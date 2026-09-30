#!/usr/bin/env python3
"""Weekly "similar music" report seeded from a NetEase liked-songs playlist.

Seeds are songs from the playlist, mostly recent likes plus some from the whole
history, one per artist. Two columns come out of them:

* 同圈子 (same scene): NetEase "similar songs" for each seed. Tight, but only
  five songs per seed, so it gets more seeds than the other column.
* 延伸 (further out): ListenBrainz similar artists for each seed artist, plus
  YouTube Music song radio while ytmusicapi can parse YouTube's pages. Neither
  is limited by NetEase's catalogue, so the top picks are checked against
  NetEase and flagged when it does not have them.

An artist scores one point per distinct seed that leads to them. Artists that
several seeds point at are shown first; single-seed artists only fill up a
short column. Artists already in the playlist or the beets library are never
recommended. The result is a static HTML page.
"""

from __future__ import annotations

import argparse
import contextlib
import dataclasses
import datetime as dt
import html
import json
import random
import re
import sqlite3
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Iterable
from pathlib import Path

NETEASE = "https://music.163.com"
USER_AGENT = "music-discover/1.0 (+https://github.com/Konakonai/nixos-config)"

CJK_RANGE = f"{chr(0x3400)}-{chr(0x9FFF)}"
CJK_RUN = re.compile(rf"[{CJK_RANGE}]+")
# "Kidney 腰乐队" -> ("Kidney", "腰乐队"), as in the beets zhlyrics plugin.
BILINGUAL = re.compile(rf"^(?P<latin>[^{CJK_RANGE}]*?)\s*(?P<cjk>[{CJK_RANGE}].*)$")
BAND_SUFFIX = re.compile(r"(乐队|乐团|组合)$")
PUNCT = re.compile(r"[\s\-_.·・,，'’&()（）\[\]]+")

RECENT_DAYS = 90
# (recent, whole history) seed quotas per column.
NETEASE_SEEDS = (100, 50)
FURTHER_SEEDS = (40, 20)
PER_COLUMN = 20
# Show single-seed artists only while the column has fewer than this.
MIN_SHOWN = 8
LISTENBRAINZ_SIMILAR = 25
YOUTUBE_PROBE = 3
REASONS_SHOWN = 3
TRACKS_SHOWN = 3


def log(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


# --- names -------------------------------------------------------------------


class Names:
    """Normalize artist names so spellings across services compare equal."""

    def __init__(self) -> None:
        try:
            import opencc

            self._t2s = opencc.OpenCC("t2s").convert
        except ImportError:  # tests run without OpenCC
            self._t2s = lambda s: s

    def key(self, name: str) -> str:
        return PUNCT.sub("", self._t2s(name).casefold())

    def keys(self, name: str) -> set[str]:
        """The name itself plus the Chinese and Latin parts of a bilingual
        name, in either order ("Kidney 腰乐队", "田馥甄 Hebe Tien")."""
        keys = {self.key(name)}
        cjk = "".join(CJK_RUN.findall(name))
        if cjk and cjk != name.strip():
            cjk = self.key(cjk)
            keys |= {cjk, BAND_SUFFIX.sub("", cjk), self.key(CJK_RUN.sub(" ", name))}
        # Single characters ("腰") would match far too much on their own.
        return {k for k in keys if len(k) >= 2 or k == self.key(name)}

    @staticmethod
    def spellings(name: str) -> list[str]:
        """Search spellings, Latin half first: MusicBrainz lists Chinese acts
        under either their English name or a short Chinese one."""
        if match := BILINGUAL.match(name.strip()):
            halves = [match["latin"].strip(), match["cjk"].strip()]
            return list(dict.fromkeys(h for h in [*halves, name] if h))
        return [name]


# --- data --------------------------------------------------------------------


@dataclasses.dataclass
class Song:
    id: int
    name: str
    artists: list[tuple[int, str]]
    liked_at: int = 0

    @property
    def artist(self) -> str:
        return self.artists[0][1] if self.artists else ""


@dataclasses.dataclass
class Track:
    title: str
    url: str


@dataclasses.dataclass
class Candidate:
    name: str
    url: str
    seeds: dict[int, Song] = dataclasses.field(default_factory=dict)
    tracks: list[Track] = dataclasses.field(default_factory=list)
    on_netease: bool | None = None
    seen_before: bool = False

    @property
    def score(self) -> int:
        return len(self.seeds)

    def add(self, seed: Song, track: Track | None = None) -> None:
        self.seeds[seed.id] = seed
        if track and track.title not in {t.title for t in self.tracks}:
            self.tracks.append(track)


class Paced:
    """Minimum spacing between requests to one service, with backoff when it
    still answers "slow down" (MusicBrainz and ListenBrainz use 503/429)."""

    MIN_INTERVAL = 1.0
    RETRY_AFTER = (5, 15, 30)

    def __init__(self) -> None:
        self._last = 0.0

    def pace(self) -> None:
        wait = self._last + self.MIN_INTERVAL - time.monotonic()
        if wait > 0:
            time.sleep(wait)
        self._last = time.monotonic()

    def fetch_json(self, url: str, headers: dict[str, str] | None = None):
        request = urllib.request.Request(
            url, headers={"User-Agent": USER_AGENT, **(headers or {})}
        )
        for delay in (*self.RETRY_AFTER, None):
            self.pace()
            try:
                with urllib.request.urlopen(request, timeout=30) as response:
                    return json.load(response)
            except urllib.error.HTTPError as exc:
                if exc.code not in (429, 503) or delay is None:
                    raise
                exc.close()
                log(f"HTTP {exc.code}, retrying in {delay}s")
                time.sleep(delay)


# --- NetEase -----------------------------------------------------------------


class RateLimited(RuntimeError):
    pass


class NetEase(Paced):
    # Same pacing and circuit breaker as the beets plugin: bursts get
    # "操作频繁" (code 405) for minutes. If backing off does not clear it,
    # stop asking for the rest of the run instead of stalling every request.
    # A run makes ~300 requests; it runs unattended, so pace it gently.
    MIN_INTERVAL = 2.5
    BACKOFF = (10, 30, 60)
    HEADERS = {"Referer": NETEASE, "User-Agent": "Mozilla/5.0"}

    def __init__(self) -> None:
        super().__init__()
        self.blocked = False

    def get(self, path: str, **params) -> dict:
        if self.blocked:
            raise RateLimited("NetEase is rate limiting this IP")
        url = f"{NETEASE}{path}?{urllib.parse.urlencode(params)}"
        for delay in (*self.BACKOFF, None):
            data = self.fetch_json(url, self.HEADERS)
            if data.get("code") != 405:
                return data
            if delay is None:
                break
            log(f"NetEase rate limit, retrying in {delay}s")
            time.sleep(delay)
        self.blocked = True
        log("NetEase still rate limited; not asking it again this run")
        raise RateLimited("NetEase is rate limiting this IP")

    def liked(self, playlist_id: int, cache: dict[str, dict]) -> list[Song]:
        """All songs of a playlist. Without login the playlist endpoint only
        details the first few tracks, but it lists every track ID, and song
        details can be fetched by ID in batches of 100."""
        data = self.get("/api/v6/playlist/detail", id=playlist_id, n=100000)
        entries = data["playlist"]["trackIds"]
        missing = [e["id"] for e in entries if str(e["id"]) not in cache]
        for i in range(0, len(missing), 100):
            c = json.dumps([{"id": song_id} for song_id in missing[i : i + 100]])
            for song in self.get("/api/v3/song/detail", c=c).get("songs") or []:
                cache[str(song["id"])] = {
                    "name": song["name"],
                    "artists": [[a["id"], a["name"]] for a in song["ar"]],
                }
        songs = []
        for entry in entries:
            if detail := cache.get(str(entry["id"])):
                artists = [tuple(a) for a in detail["artists"]]
                songs.append(
                    Song(entry["id"], detail["name"], artists, entry.get("at", 0))
                )
        return songs

    def similar(self, song_id: int) -> list[Song]:
        data = self.get("/api/discovery/simiSong", songid=song_id, limit=10)
        return [
            Song(s["id"], s["name"], [(a["id"], a["name"]) for a in s["artists"]])
            for s in data.get("songs") or []
        ]

    def find_artist(
        self, artist: str, titles: list[str], names: Names
    ) -> tuple[int, str] | None:
        """NetEase (id, name) for an artist named by another service.

        Artist search understands many aliases ("Hebe Tien" -> 田馥甄), but
        its top hit is not always the artist ("Björk" -> "Jon Björk"), so a
        hit only counts when a name or alias matches. Romanized names
        ("Sun Yanzi") are then found through a song title, which services
        rarely transliterate."""
        wanted = names.keys(artist)
        data = self.get("/api/search/get/web", s=artist, type=100, limit=5)
        for a in (data.get("result") or {}).get("artists") or []:
            spellings = [a["name"], *(a.get("alias") or []), a.get("trans") or ""]
            if any(names.keys(s) & wanted for s in spellings if s):
                return a["id"], a["name"]
        for title in titles[:2]:
            data = self.get("/api/search/get/web", s=title, type=1, limit=30)
            for song in (data.get("result") or {}).get("songs") or []:
                if names.key(song["name"]) == names.key(title) and song["artists"]:
                    return song["artists"][0]["id"], song["artists"][0]["name"]
        return None

    def top_tracks(self, artist_id: int) -> list[Track]:
        data = self.get("/api/artist/top/song", id=artist_id)
        return [
            Track(s["name"], netease_song_url(s["id"]))
            for s in (data.get("songs") or [])[:TRACKS_SHOWN]
        ]


def netease_song_url(song_id: int) -> str:
    return f"{NETEASE}/#/song?id={song_id}"


def netease_artist_url(artist_id: int) -> str:
    return f"{NETEASE}/#/artist?id={artist_id}"


# --- ListenBrainz ------------------------------------------------------------


class ListenBrainz(Paced):
    # MusicBrainz allows one request per second per client.
    MIN_INTERVAL = 1.1
    SEARCH = "https://musicbrainz.org/ws/2/artist"
    SIMILAR = "https://labs.api.listenbrainz.org/similar-artists/json"
    ALGORITHM = (
        "session_based_days_7500_session_300_contribution_5_threshold_10"
        "_limit_100_filter_True_skip_30"
    )

    def mbid(self, artist: str, names: Names, cache: dict[str, str]) -> str:
        """MusicBrainz ID for an artist name, or "" if it cannot be matched."""
        if artist in cache:
            return cache[artist]
        wanted = names.keys(artist)
        found = ""
        for spelling in Names.spellings(artist):
            quoted = spelling.replace('"', "")
            query = f'artist:"{quoted}" OR alias:"{quoted}"'
            url = f"{self.SEARCH}?{urllib.parse.urlencode({'query': query, 'fmt': 'json', 'limit': 3})}"
            for result in self.fetch_json(url).get("artists") or []:
                spellings = [result["name"]] + [
                    a["name"] for a in result.get("aliases") or []
                ]
                if result.get("score", 0) >= 90 and any(
                    names.keys(s) & wanted for s in spellings
                ):
                    found = result["id"]
                    break
            if found:
                break
        cache[artist] = found
        return found

    def similar(self, mbid: str) -> list[tuple[str, str]]:
        """(name, mbid) of the most similar artists."""
        params = urllib.parse.urlencode(
            {"artist_mbids": mbid, "algorithm": self.ALGORITHM}
        )
        data = self.fetch_json(f"{self.SIMILAR}?{params}")
        if isinstance(data, dict):
            data = data.get("payload") or data.get("data") or []
        return [
            (a["name"], a["artist_mbid"])
            for a in data[:LISTENBRAINZ_SIMILAR]
            if a.get("name") and a.get("artist_mbid") != mbid
        ]


# --- YouTube Music -----------------------------------------------------------


class YouTubeMusic(Paced):
    """Song radio via ytmusicapi. Unofficial: it breaks whenever YouTube
    changes its pages, and then returns empty results instead of failing."""

    def __init__(self) -> None:
        super().__init__()
        from ytmusicapi import YTMusic

        self._yt = YTMusic()

    def radio(self, seed: Song) -> list[tuple[str, Track]]:
        self.pace()
        found = self._yt.search(f"{seed.artist} {seed.name}", filter="songs", limit=1)
        if not found:
            return []
        video_id = found[0]["videoId"]
        self.pace()
        radio = self._yt.get_watch_playlist(videoId=video_id, radio=True, limit=25)
        results = []
        for track in radio.get("tracks") or []:
            # User uploads come from compilation/"chill" channels whose names
            # show up as artists in every radio; keep official audio/videos.
            if track.get("videoId") == video_id or track.get("videoType") == UGC:
                continue
            url = f"https://music.youtube.com/watch?v={track['videoId']}"
            for artist in track.get("artists") or []:
                results.append((artist["name"], Track(track["title"], url)))
        return results


UGC = "MUSIC_VIDEO_TYPE_UGC"


def youtube_search_url(query: str) -> str:
    return "https://music.youtube.com/search?q=" + urllib.parse.quote(query)


# --- selection and scoring ---------------------------------------------------


def pick_seeds(
    songs: list[Song], now: dt.datetime, rng: random.Random, quotas: tuple[int, int]
) -> list[Song]:
    """Mostly recent likes, some from the whole history, one per artist."""
    cutoff = (now - dt.timedelta(days=RECENT_DAYS)).timestamp() * 1000
    recent = [s for s in songs if s.liked_at >= cutoff]
    rng.shuffle(recent)
    rest = [s for s in songs if s.liked_at < cutoff]
    rng.shuffle(rest)

    seeds, artists = [], set()
    for pool, quota in ((recent, quotas[0]), (rest + recent, quotas[1])):
        taken = 0
        for song in pool:
            if taken == quota:
                break
            if song.artist and song.artist not in artists:
                artists.add(song.artist)
                seeds.append(song)
                taken += 1
    return seeds


def known_artists(names: Names, playlist: Iterable[Song], library: Iterable[str]):
    known: set[str] = set()
    for song in playlist:
        for _, name in song.artists:
            known |= names.keys(name)
    for name in library:
        known |= names.keys(name)
    return known


def is_known(names: Names, name: str, known: set[str]) -> bool:
    return bool(names.keys(name) & known)


def rank(
    candidates: dict[str, Candidate],
    limit: int = PER_COLUMN,
    min_shown: int = MIN_SHOWN,
) -> list[Candidate]:
    """Best first; single-seed artists only pad out a short list."""
    ordered = sorted(
        candidates.values(), key=lambda c: (-c.score, -len(c.tracks), c.name)
    )
    strong = [c for c in ordered if c.score >= 2]
    weak = [c for c in ordered if c.score < 2]
    return (strong + weak[: max(0, min_shown - len(strong))])[:limit]


def library_artists(db: Path) -> list[str]:
    if not db.exists():
        return []
    with contextlib.closing(sqlite3.connect(f"file:{db}?mode=ro", uri=True)) as conn:
        rows = conn.execute(
            "select distinct artist from items union select distinct albumartist from items"
        )
        return [row[0] for row in rows if row[0]]


# --- page --------------------------------------------------------------------

PAGE = """<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>音乐发现</title>
<style>
:root {{ --bg:#fafaf9; --fg:#1c1917; --muted:#78716c; --card:#fff; --line:#e7e5e4; --accent:#b45309; --warn:#b91c1c; }}
@media (prefers-color-scheme: dark) {{ :root {{ --bg:#1c1917; --fg:#f5f5f4; --muted:#a8a29e; --card:#292524; --line:#44403c; --accent:#f59e0b; --warn:#f87171; }} }}
* {{ box-sizing:border-box; }}
body {{ margin:0; background:var(--bg); color:var(--fg); font:15px/1.55 system-ui, "PingFang SC", "Noto Sans CJK SC", sans-serif; }}
header, main {{ max-width:1100px; margin:0 auto; padding:16px; }}
h1 {{ font-size:22px; margin:8px 0 4px; }}
.meta {{ color:var(--muted); font-size:13px; }}
main {{ display:grid; grid-template-columns:1fr 1fr; gap:24px; }}
@media (max-width:760px) {{ main {{ grid-template-columns:1fr; }} }}
h2 {{ font-size:17px; margin:0 0 4px; }}
h2 + p {{ color:var(--muted); font-size:13px; margin:0 0 12px; }}
.card {{ background:var(--card); border:1px solid var(--line); border-radius:10px; padding:12px 14px; margin-bottom:10px; }}
.card h3 {{ font-size:16px; margin:0; display:flex; gap:8px; align-items:baseline; flex-wrap:wrap; }}
.card h3 a {{ color:inherit; }}
.score {{ color:var(--accent); font-weight:600; font-size:13px; }}
.tag {{ font-size:11px; border:1px solid currentColor; border-radius:4px; padding:0 4px; color:var(--muted); }}
.tag.warn {{ color:var(--warn); }}
.why {{ color:var(--muted); font-size:13px; margin:4px 0; }}
ul {{ margin:4px 0 0; padding-left:18px; }}
a {{ color:var(--accent); text-decoration:none; }}
.error {{ color:var(--warn); }}
</style>
</head>
<body>
<header>
<h1>音乐发现</h1>
<div class="meta">{generated} · 种子取自「我喜欢的音乐」（最近 {recent_days} 天的收藏为主，每个艺人一首）· 已排除歌单与曲库里的 {known} 个艺人名 · ×N 表示有 N 首你喜欢的歌指向这个艺人</div>
</header>
<main>
<section>
<h2>同圈子</h2>
<p>网易云「相似歌曲」，{netease_seeds} 首种子。</p>
{netease}
</section>
<section>
<h2>延伸</h2>
<p>ListenBrainz 相似艺人{youtube_status}，{further_seeds} 首种子；「网易云无」表示网易云搜不到这个艺人。</p>
{further}
</section>
</main>
</body>
</html>
"""


def render_column(candidates: list[Candidate], error: str | None) -> str:
    if error:
        return f'<p class="error">这一栏本周没有生成：{html.escape(error)}</p>'
    if not candidates:
        return '<p class="meta">本周没有新发现。</p>'
    cards = []
    for c in candidates:
        tags = ""
        if c.on_netease is False:
            tags += '<span class="tag warn">网易云无</span>'
        if c.seen_before:
            tags += '<span class="tag">已推过</span>'
        reasons = "、".join(
            f"{html.escape(s.artist)}《{html.escape(s.name)}》"
            for s in list(c.seeds.values())[:REASONS_SHOWN]
        )
        tracks = [
            f'<li><a href="{html.escape(t.url)}">{html.escape(t.title)}</a></li>'
            for t in c.tracks[:TRACKS_SHOWN]
        ] or [
            f'<li><a href="{html.escape(youtube_search_url(c.name))}">在 YouTube Music 搜索</a></li>'
        ]
        cards.append(
            f'<div class="card"><h3><a href="{html.escape(c.url)}">{html.escape(c.name)}</a>'
            f'<span class="score">×{c.score}</span>{tags}</h3>'
            f'<div class="why">因为你喜欢 {reasons}</div><ul>{"".join(tracks)}</ul></div>'
        )
    return "\n".join(cards)


def render(
    now: dt.datetime,
    known: int,
    netease: list[Candidate],
    further: list[Candidate],
    netease_seeds: int = 0,
    further_seeds: int = 0,
    netease_error: str | None = None,
    further_error: str | None = None,
    youtube_ok: bool = True,
) -> str:
    return PAGE.format(
        generated=now.strftime("%Y-%m-%d %H:%M"),
        recent_days=RECENT_DAYS,
        known=known,
        netease_seeds=netease_seeds,
        further_seeds=further_seeds,
        youtube_status=(
            " + YouTube Music 歌曲电台"
            if youtube_ok
            else "（YouTube Music 本周不可用，未计入）"
        ),
        netease=render_column(netease, netease_error),
        further=render_column(further, further_error),
    )


# --- main --------------------------------------------------------------------


def load_json(path: Path, default):
    try:
        return json.loads(path.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return default


def collect_netease(netease, names, known, seeds) -> dict[str, Candidate]:
    candidates: dict[str, Candidate] = {}
    for i, seed in enumerate(seeds, 1):
        log(f"[netease {i}/{len(seeds)}] {seed.artist} - {seed.name}")
        try:
            similar = netease.similar(seed.id)
        except RateLimited:
            if i == 1:
                raise
            log(f"netease: stopping after {i - 1} seeds, keeping what was found")
            break
        for song in similar:
            for artist_id, artist in song.artists[:1]:
                if not is_known(names, artist, known):
                    candidates.setdefault(
                        names.key(artist),
                        Candidate(artist, netease_artist_url(artist_id)),
                    ).add(seed, Track(song.name, netease_song_url(song.id)))
    return candidates


def collect_further(names, known, seeds, mbids) -> tuple[dict[str, Candidate], bool]:
    candidates: dict[str, Candidate] = {}

    def add(artist: str, seed: Song, track: Track | None = None) -> None:
        if not is_known(names, artist, known):
            candidates.setdefault(
                names.key(artist), Candidate(artist, youtube_search_url(artist))
            ).add(seed, track)

    listenbrainz = ListenBrainz()
    failures = 0
    for i, seed in enumerate(seeds, 1):
        log(f"[listenbrainz {i}/{len(seeds)}] {seed.artist}")
        try:
            if mbid := listenbrainz.mbid(seed.artist, names, mbids):
                for artist, _ in listenbrainz.similar(mbid):
                    add(artist, seed)
        except Exception as exc:  # one bad seed must not sink the column
            failures += 1
            log(f"  skipped: {type(exc).__name__}: {exc}")
    if seeds and failures == len(seeds):
        raise RuntimeError("ListenBrainz/MusicBrainz failed for every seed")

    youtube_ok = False
    try:
        youtube = YouTubeMusic()
        for i, seed in enumerate(seeds, 1):
            if i > YOUTUBE_PROBE and not youtube_ok:
                log("youtube: no results from the first seeds, skipping it")
                break
            log(f"[youtube {i}/{len(seeds)}] {seed.artist} - {seed.name}")
            for artist, track in youtube.radio(seed):
                youtube_ok = True
                add(artist, seed, track)
    except Exception as exc:
        log(f"youtube failed: {type(exc).__name__}: {exc}")
    return candidates, youtube_ok


def resolve_on_netease(netease, names, known, ranked) -> list[Candidate]:
    """Look the top "further" picks up on NetEase: flag the ones it lacks,
    link the rest to their NetEase page, and drop artists that turn out to be
    known under their NetEase name ("Hebe Tien" is 田馥甄)."""
    kept: list[Candidate] = []
    for c in ranked:
        if len(kept) == PER_COLUMN:
            break
        try:
            found = netease.find_artist(c.name, [t.title for t in c.tracks], names)
        except Exception as exc:
            log(f"netease lookup failed for {c.name}: {exc}")
            kept.append(c)
            continue
        c.on_netease = found is not None
        if found:
            artist_id, netease_name = found
            if is_known(names, netease_name, known):
                log(f"  {c.name} is {netease_name}, already known")
                continue
            if names.key(netease_name) != names.key(c.name):
                c.name = f"{netease_name}（{c.name}）"
            c.url = netease_artist_url(artist_id)
            try:
                c.tracks = netease.top_tracks(artist_id) or c.tracks
            except Exception as exc:
                log(f"netease top songs failed for {netease_name}: {exc}")
        kept.append(c)
    return kept


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--playlist", type=int, required=True)
    parser.add_argument("--library-db", type=Path, required=True)
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    now = dt.datetime.now()
    week = now.strftime("%G-W%V")
    args.state.mkdir(parents=True, exist_ok=True)
    args.out.mkdir(parents=True, exist_ok=True)
    songs_path = args.state / "songs.json"
    mbids_path = args.state / "mbids.json"
    history_path = args.state / "history.json"
    song_cache = load_json(songs_path, {})
    mbids = load_json(mbids_path, {})
    history: dict[str, str] = load_json(history_path, {})

    names = Names()
    netease = NetEase()
    log("reading liked songs")
    liked = netease.liked(args.playlist, song_cache)
    songs_path.write_text(json.dumps(song_cache, ensure_ascii=False))
    known = known_artists(names, liked, library_artists(args.library_db))
    # Same seeds for reruns within a week.
    netease_seeds = pick_seeds(liked, now, random.Random(week), NETEASE_SEEDS)
    further_seeds = pick_seeds(liked, now, random.Random(week), FURTHER_SEEDS)
    log(f"{len(liked)} liked songs, {len(known)} known artist names")

    netease_top, netease_error = [], None
    try:
        netease_top = rank(collect_netease(netease, names, known, netease_seeds))
    except Exception as exc:  # keep the other column
        netease_error = f"{type(exc).__name__}: {exc}"
        log(f"netease failed: {netease_error}")

    further_ranked, further_error, youtube_ok = [], None, False
    try:
        candidates, youtube_ok = collect_further(names, known, further_seeds, mbids)
        shown = {names.key(c.name) for c in netease_top}
        further_ranked = rank(
            {k: c for k, c in candidates.items() if k not in shown},
            limit=len(candidates),
        )
    except Exception as exc:
        further_error = f"{type(exc).__name__}: {exc}"
        log(f"further failed: {further_error}")
    finally:
        mbids_path.write_text(json.dumps(mbids, ensure_ascii=False))

    further_top = resolve_on_netease(netease, names, known, further_ranked)

    for c in netease_top + further_top:
        key = names.key(c.name)
        c.seen_before = history.get(key, week) != week
        history.setdefault(key, week)
    history_path.write_text(json.dumps(history, ensure_ascii=False, indent=0))

    page = render(
        now,
        len(known),
        netease_top,
        further_top,
        len(netease_seeds),
        len(further_seeds),
        netease_error,
        further_error,
        youtube_ok,
    )
    (args.out / f"{week}.html").write_text(page)
    (args.out / "index.html").write_text(page)
    log(f"wrote {args.out / 'index.html'}")
    return 1 if netease_error and further_error else 0


if __name__ == "__main__":
    sys.exit(main())
