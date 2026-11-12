#!/usr/bin/env python3
"""Weekly "similar music" report seeded from a NetEase liked-songs playlist.

Seeds are songs from the playlist, one per artist, spread across genre
buckets (MusicBrainz tags, else a language guess) so that one heavily liked
genre cannot fill the page; within a bucket, recently liked artists go first.
Two columns come out of them:

* 同圈子 (same scene): NetEase "similar songs" for each seed. Tight, but only
  five songs per seed, so it gets more seeds than the other column.
* 延伸 (further out): ListenBrainz similar artists for each seed artist, plus
  YouTube Music song radio while ytmusicapi can parse YouTube's pages. Neither
  is limited by NetEase's catalogue, so the top picks are checked against
  NetEase and flagged when it does not have them.

An artist scores one point per distinct seed that leads to them. Artists that
several seeds point at are shown first; single-seed artists only fill up a
short column. Artists with very many NetEase followers are probably known and
passed over, so they are tagged and moved to the back. Artists already liked,
followed on NetEase, or in the beets library are never recommended. The
result is a static HTML page.
"""

from __future__ import annotations

import argparse
import collections
import contextlib
import dataclasses
import datetime as dt
import html
import json
import math
import random
import re
import sqlite3
import sys
import tempfile
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
KANA = re.compile(f"[{chr(0x3040)}-{chr(0x30FF)}]")

# Coarse genre buckets for balancing seeds, matched against MusicBrainz tags
# (most-voted first). Order matters: "trip hop" is electronic, not hip hop;
# "indie pop" is pop and "indie rock" is rock; "folk rock" counts as folk.
GENRES = [
    ("金属", ("metal",)),
    (
        "电子",
        (
            "electronic",
            "techno",
            "house",
            "ambient",
            "idm",
            "downtempo",
            "trip hop",
            "trip-hop",
            "edm",
            "electro",
            "drum and bass",
            "dubstep",
            "synthwave",
            "breakbeat",
            "glitch",
            "vaporwave",
        ),
    ),
    ("嘻哈", ("hip hop", "hip-hop", "rap", "trap")),
    ("爵士/灵魂", ("jazz", "soul", "r&b", "rnb", "funk", "blues", "disco")),
    (
        "古典/原声",
        (
            "classical",
            "orchestral",
            "baroque",
            "opera",
            "soundtrack",
            "neoclassical",
            "minimalism",
        ),
    ),
    ("实验", ("experimental", "avant-garde", "noise", "free improvisation")),
    ("民谣", ("folk", "singer-songwriter", "acoustic", "country", "americana")),
    ("流行", ("pop", "idol", "kayōkyoku", "kayokyoku")),
    (
        "摇滚",
        (
            "rock",
            "punk",
            "shoegaze",
            "grunge",
            "emo",
            "new wave",
            "indie",
            "psychedelic",
            "krautrock",
        ),
    ),
    ("世界", ("world", "reggae", "afrobeat", "latin", "bossa nova", "flamenco")),
]
# "Kidney 腰乐队" -> ("Kidney", "腰乐队"), as in the beets zhlyrics plugin.
BILINGUAL = re.compile(rf"^(?P<latin>[^{CJK_RANGE}]*?)\s*(?P<cjk>[{CJK_RANGE}].*)$")
BAND_SUFFIX = re.compile(r"(乐队|乐团|组合)$")
PUNCT = re.compile(r"[\s\-_.·・,，'’&()（）\[\]]+")

RECENT_DAYS = 90
NETEASE_SEEDS = 100
FURTHER_SEEDS = 60
# New MusicBrainz genre lookups per run; results are cached for good.
TAG_BUDGET = 250
PER_COLUMN = 20
# Look at a few more than shown, since hot and followed artists get moved
# down or dropped.
HEADROOM = 10
# NetEase followers above which an artist is likely known but passed over.
HOT_FANS = 3_000_000
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
    netease_id: int | None = None
    fans: int | None = None

    @property
    def hot(self) -> bool:
        return (self.fans or 0) >= HOT_FANS

    @property
    def score(self) -> int:
        return len(self.seeds)

    def add(self, seed: Song, track: Track | None = None) -> None:
        self.seeds[seed.id] = seed
        if track and track.title not in {t.title for t in self.tracks}:
            self.tracks.append(track)


class Paced:
    """Minimum spacing between requests to one service, with backoff when it
    still answers "slow down" (MusicBrainz and ListenBrainz use 503/429) or
    the connection drops (TLS resets through the proxy are common here)."""

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
            except (urllib.error.URLError, TimeoutError, ConnectionError) as exc:
                if delay is None:
                    raise
                log(f"{type(exc).__name__}: {exc}, retrying in {delay}s")
            time.sleep(delay)


# --- NetEase -----------------------------------------------------------------


class RateLimited(RuntimeError):
    pass


class NetEase(Paced):
    # Same pacing and circuit breaker as the beets plugin: bursts get
    # "操作频繁" (code 405) for minutes. If backing off does not clear it,
    # stop asking for the rest of the run instead of stalling every request.
    # A run makes ~250 requests and runs unattended, so pace it gently and
    # wait out a limit for several minutes before giving up (when the limit
    # kicks in varies from run to run).
    MIN_INTERVAL = 3.0
    BACKOFF = (15, 60, 180, 300)
    HEADERS = {"Referer": NETEASE, "User-Agent": "Mozilla/5.0"}

    def __init__(self, cookie: str | None = None) -> None:
        super().__init__()
        self.blocked = False
        self.headers = dict(self.HEADERS)
        if cookie:
            # MUSIC_U is the web login session (see modules/home/music-discover.nix).
            value = cookie.strip().removeprefix("MUSIC_U=").strip()
            self.headers["Cookie"] = f"MUSIC_U={value}"

    def get(self, path: str, **params) -> dict:
        if self.blocked:
            raise RateLimited("NetEase is rate limiting this IP")
        url = f"{NETEASE}{path}?{urllib.parse.urlencode(params)}"
        for delay in (*self.BACKOFF, None):
            data = self.fetch_json(url, self.headers)
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

    def account(self) -> str | None:
        """Nickname of the logged-in account, or None when not logged in."""
        profile = self.get("/api/nuser/account/get").get("profile")
        return profile["nickname"] if profile else None

    def followed(self) -> list[tuple[int, str]]:
        """Artists the logged-in account follows."""
        artists, offset = [], 0
        while True:
            data = self.get(
                "/api/artist/sublist", limit=1000, offset=offset, total="true"
            )
            page = data.get("data") or []
            artists += [(a["id"], a["name"]) for a in page]
            if not data.get("hasMore") or not page:
                return artists
            offset += len(page)

    def fans(self, artist_id: int) -> tuple[int, bool]:
        """(follower count, whether the logged-in account follows them)."""
        data = self.get("/api/artist/follow/count/get", id=artist_id).get("data") or {}
        return data.get("fansCnt") or 0, bool(data.get("isFollow"))

    def similar_artists(self, artist_id: int) -> list[tuple[int, str]]:
        """Artist-level similarity; NetEase only answers this when logged in."""
        data = self.get("/api/discovery/simiArtist", artistid=artist_id)
        return [(a["id"], a["name"]) for a in data.get("artists") or []]

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

    def lookup(self, artist: str, names: Names, cache: dict[str, dict]) -> dict:
        """{"mbid", "tags"} for an artist name; mbid is "" if unmatched."""
        if artist in cache:
            return cache[artist]
        wanted = names.keys(artist)
        found = {"mbid": "", "tags": []}
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
                    tags = sorted(
                        ((t["count"], t["name"]) for t in result.get("tags") or []),
                        reverse=True,
                    )
                    found = {"mbid": result["id"], "tags": [t for _, t in tags]}
                    break
            if found["mbid"]:
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


def genre_of(tags: list[str], artist: str) -> str:
    """Genre bucket from MusicBrainz tags, else a language guess from the
    name (Chinese indie acts are rarely tagged on MusicBrainz)."""
    for tag in tags:
        tag = tag.casefold()
        for bucket, words in GENRES:
            if any(word in tag for word in words):
                return bucket
    if KANA.search(artist):
        return "日语（无标签）"
    if CJK_RUN.search(artist):
        return "华语（无标签）"
    return "其他（无标签）"


def bucket_quotas(sizes: dict[str, int], total: int) -> dict[str, int]:
    """Seats per bucket proportional to the square root of its size, so big
    buckets lead without drowning out small ones (largest remainders)."""
    weights = {b: math.sqrt(n) for b, n in sizes.items() if n}
    if not weights:
        return {}
    exact = {b: total * w / sum(weights.values()) for b, w in weights.items()}
    quotas = {b: min(sizes[b], int(x)) for b, x in exact.items()}
    for b in sorted(exact, key=lambda b: exact[b] - int(exact[b]), reverse=True):
        if sum(quotas.values()) >= total:
            break
        if quotas[b] < sizes[b]:
            quotas[b] += 1
    return quotas


def pick_seeds(
    songs: list[Song],
    now: dt.datetime,
    rng: random.Random,
    total: int,
    genres: dict[str, str],
) -> tuple[list[Song], dict[str, int]]:
    """One song per artist, spread across genre buckets. Within a bucket,
    artists liked in the last RECENT_DAYS come first, and each artist is
    represented by one of their recent likes when there are any."""
    cutoff = (now - dt.timedelta(days=RECENT_DAYS)).timestamp() * 1000
    by_artist: dict[str, list[Song]] = {}
    for song in songs:
        if song.artist:
            by_artist.setdefault(song.artist, []).append(song)

    buckets: dict[str, list[str]] = {}
    for artist in sorted(by_artist):
        buckets.setdefault(genres.get(artist, genre_of([], artist)), []).append(artist)

    def is_recent(artist: str) -> bool:
        return any(s.liked_at >= cutoff for s in by_artist[artist])

    quotas = bucket_quotas({b: len(a) for b, a in buckets.items()}, total)
    seeds = []
    for bucket in sorted(quotas):
        artists = buckets[bucket]
        rng.shuffle(artists)
        artists.sort(key=lambda a: not is_recent(a))
        for artist in artists[: quotas[bucket]]:
            recent = [s for s in by_artist[artist] if s.liked_at >= cutoff]
            seeds.append(rng.choice(recent or by_artist[artist]))
    return seeds, quotas


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
    uri = f"file:{urllib.parse.quote(str(db))}?mode=ro"
    with contextlib.closing(sqlite3.connect(uri, uri=True)) as conn:
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
.fans {{ color:var(--muted); font-size:12px; }}
ul {{ margin:4px 0 0; padding-left:18px; }}
a {{ color:var(--accent); text-decoration:none; }}
.error {{ color:var(--warn); }}
</style>
</head>
<body>
<header>
<h1>音乐发现</h1>
<div class="meta">{generated} · 种子取自「我喜欢的音乐」，按风格均衡抽取（最近 {recent_days} 天收藏的艺人优先，每个艺人一首）：{seed_mix}</div>
<div class="meta">已排除收藏、关注与曲库里的 {known} 个艺人名 · ×N 表示有 N 首你喜欢的歌指向这个艺人 · 网易云粉丝超过 {hot_fans} 的标「大热」并排在后面</div>
</header>
<main>
<section>
<h2>同圈子</h2>
<p>{netease_source}，{netease_seeds} 首种子。</p>
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


def format_fans(n: int) -> str:
    if n >= 1_000_000:
        return f"{n / 10_000:.0f}万"
    if n >= 10_000:
        return f"{n / 10_000:.1f}万"
    return str(n)


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
        if c.hot:
            tags += '<span class="tag">大热</span>'
        if c.seen_before:
            tags += '<span class="tag">已推过</span>'
        if c.fans is not None:
            tags += f'<span class="fans">粉丝 {format_fans(c.fans)}</span>'
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
    netease_source: str = "网易云「相似歌曲」",
    seed_mix: str = "",
) -> str:
    return PAGE.format(
        netease_source=html.escape(netease_source),
        seed_mix=html.escape(seed_mix),
        hot_fans=format_fans(HOT_FANS),
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


def write_json(path: Path, data, **kwargs) -> None:
    """Replace path atomically: load_json treats a torn file as empty, so an
    interrupted plain write would silently drop the whole cache."""
    with tempfile.NamedTemporaryFile(
        "w", dir=path.parent, prefix=f".{path.name}.", delete=False
    ) as handle:
        tmp = Path(handle.name)
        try:
            json.dump(data, handle, ensure_ascii=False, **kwargs)
        except BaseException:
            tmp.unlink()
            raise
    try:
        tmp.replace(path)
    except BaseException:
        tmp.unlink(missing_ok=True)
        raise


def collect_netease(
    netease, names, known, seeds, by_artist: bool = False, known_ids=frozenset()
) -> dict[str, Candidate]:
    """Similar artists per seed artist when logged in, else similar songs."""
    candidates: dict[str, Candidate] = {}
    for i, seed in enumerate(seeds, 1):
        log(f"[netease {i}/{len(seeds)}] {seed.artist} - {seed.name}")
        try:
            if by_artist:
                similar_artists = netease.similar_artists(seed.artists[0][0])
            else:
                similar = netease.similar(seed.id)
        except RateLimited:
            if i == 1:
                raise
            log(f"netease: stopping after {i - 1} seeds, keeping what was found")
            break
        if by_artist:
            for artist_id, artist in similar_artists:
                if artist_id not in known_ids and not is_known(names, artist, known):
                    candidate = candidates.setdefault(
                        names.key(artist),
                        Candidate(artist, netease_artist_url(artist_id)),
                    )
                    candidate.netease_id = artist_id
                    candidate.add(seed)
            continue
        for song in similar:
            for artist_id, artist in song.artists[:1]:
                if artist_id not in known_ids and not is_known(names, artist, known):
                    candidate = candidates.setdefault(
                        names.key(artist),
                        Candidate(artist, netease_artist_url(artist_id)),
                    )
                    candidate.netease_id = artist_id
                    candidate.add(seed, Track(song.name, netease_song_url(song.id)))
    return candidates


def collect_further(
    listenbrainz, names, known, seeds, artist_info
) -> tuple[dict[str, Candidate], bool]:
    candidates: dict[str, Candidate] = {}

    def add(artist: str, seed: Song, track: Track | None = None) -> None:
        if not is_known(names, artist, known):
            candidates.setdefault(
                names.key(artist), Candidate(artist, youtube_search_url(artist))
            ).add(seed, track)

    failures = 0
    for i, seed in enumerate(seeds, 1):
        log(f"[listenbrainz {i}/{len(seeds)}] {seed.artist}")
        try:
            if mbid := listenbrainz.lookup(seed.artist, names, artist_info)["mbid"]:
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


def resolve_on_netease(
    netease,
    names,
    known,
    ranked,
    limit: int = PER_COLUMN + HEADROOM,
    skip_ids=frozenset(),
) -> list[Candidate]:
    """Look the top "further" picks up on NetEase: flag the ones it lacks,
    link the rest to their NetEase page, and drop artists that turn out to be
    known under their NetEase name ("Hebe Tien" is 田馥甄), or whose NetEase
    id is in `skip_ids` or already kept (the NetEase column may show 田馥甄
    under a name no key of "Hebe Tien" matches)."""
    seen_ids = set(skip_ids)
    kept: list[Candidate] = []
    for c in ranked:
        if len(kept) == limit:
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
            if artist_id in seen_ids or is_known(names, netease_name, known):
                log(f"  {c.name} is {netease_name}, already known or shown")
                continue
            seen_ids.add(artist_id)
            if names.key(netease_name) != names.key(c.name):
                c.name = f"{netease_name}（{c.name}）"
            c.url = netease_artist_url(artist_id)
            c.netease_id = artist_id
        kept.append(c)
    return kept


def finish_column(netease, ranked: list[Candidate]) -> list[Candidate]:
    """Fan counts, then followed artists out and hot artists to the back,
    then NetEase top songs for the ones shown."""
    kept = []
    for c in ranked:
        if c.netease_id:
            try:
                c.fans, following = netease.fans(c.netease_id)
            except Exception as exc:
                log(f"netease fans failed for {c.name}: {exc}")
                following = False
            if following:
                log(f"  already following {c.name}")
                continue
        kept.append(c)
    shown = ([c for c in kept if not c.hot] + [c for c in kept if c.hot])[:PER_COLUMN]
    for c in shown:
        # NetEase links beat YouTube ones for artists NetEase has.
        if c.netease_id and not any(NETEASE in t.url for t in c.tracks):
            try:
                c.tracks = netease.top_tracks(c.netease_id) or c.tracks
            except Exception as exc:
                log(f"netease top songs failed for {c.name}: {exc}")
    return shown


def tag_artists(listenbrainz, names, liked, artist_info, budget: int) -> None:
    """Fetch MusicBrainz genre tags for liked artists not seen before, most
    liked first, up to `budget` per run. Skips artists that fail; gives up on
    MusicBrainz after a run of failures and balances with what it has."""
    counts = collections.Counter(s.artist for s in liked if s.artist)
    todo = [a for a, _ in counts.most_common() if a not in artist_info][:budget]
    failures = 0
    for i, artist in enumerate(todo, 1):
        if i % 50 == 1:
            log(f"[tags {i}/{len(todo)}] {artist}")
        try:
            listenbrainz.lookup(artist, names, artist_info)
            failures = 0
        except Exception as exc:
            failures += 1
            log(f"  tags for {artist} failed: {type(exc).__name__}: {exc}")
            if failures == 5:
                log("tag lookup stopped after 5 failures in a row")
                return


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--playlist", type=int, required=True)
    parser.add_argument("--library-db", type=Path, required=True)
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument(
        "--cookie-file", type=Path, help="file holding the NetEase MUSIC_U cookie"
    )
    parser.add_argument(
        "--tag-budget",
        type=int,
        default=TAG_BUDGET,
        help="MusicBrainz genre lookups this run (raise once to tag a new library)",
    )
    args = parser.parse_args()

    now = dt.datetime.now()
    week = now.strftime("%G-W%V")
    args.state.mkdir(parents=True, exist_ok=True)
    args.out.mkdir(parents=True, exist_ok=True)
    songs_path = args.state / "songs.json"
    artists_path = args.state / "artists.json"
    history_path = args.state / "history.json"
    song_cache = load_json(songs_path, {})
    artist_info: dict[str, dict] = load_json(artists_path, {})
    history: dict[str, str] = load_json(history_path, {})

    names = Names()
    cookie = None
    if args.cookie_file and args.cookie_file.exists():
        cookie = args.cookie_file.read_text().strip() or None
    netease = NetEase(cookie)
    logged_in = False
    if cookie:
        try:
            nickname = netease.account()
        except Exception as exc:
            nickname = None
            log(f"netease login check failed: {exc}")
        logged_in = nickname is not None
        log(
            f"netease: logged in as {nickname}"
            if logged_in
            else "netease: cookie rejected"
        )
    netease_source = (
        "网易云「相似艺人」"
        if logged_in
        else "网易云「相似歌曲」"
        + ("（登录 cookie 已失效，按未登录处理）" if cookie else "")
    )

    log("reading liked songs")
    liked = netease.liked(args.playlist, song_cache)
    write_json(songs_path, song_cache)
    known = known_artists(names, liked, library_artists(args.library_db))
    known_ids = {artist_id for s in liked for artist_id, _ in s.artists}
    if logged_in:
        try:
            followed = netease.followed()
            known |= known_artists(names, [], [name for _, name in followed])
            known_ids |= {artist_id for artist_id, _ in followed}
            log(f"{len(followed)} followed artists")
        except Exception as exc:
            log(f"followed artists failed: {exc}")
    log(f"{len(liked)} liked songs, {len(known)} known artist names")

    listenbrainz = ListenBrainz()
    try:
        tag_artists(listenbrainz, names, liked, artist_info, args.tag_budget)
    finally:
        write_json(artists_path, artist_info)
    genres = {a: genre_of(info.get("tags") or [], a) for a, info in artist_info.items()}
    # Same seeds for reruns within a week.
    netease_seeds, mix = pick_seeds(
        liked, now, random.Random(week), NETEASE_SEEDS, genres
    )
    further_seeds, _ = pick_seeds(
        liked, now, random.Random(f"{week}/further"), FURTHER_SEEDS, genres
    )
    seed_mix = " · ".join(
        f"{b} {n}" for b, n in sorted(mix.items(), key=lambda x: -x[1])
    )
    log(f"seed mix: {seed_mix}")

    netease_top, netease_error = [], None
    try:
        candidates = collect_netease(
            netease, names, known, netease_seeds, logged_in, known_ids
        )
        netease_top = finish_column(
            netease, rank(candidates, limit=PER_COLUMN + HEADROOM)
        )
    except Exception as exc:  # keep the other column
        netease_error = f"{type(exc).__name__}: {exc}"
        log(f"netease failed: {netease_error}")

    further_top, further_error, youtube_ok = [], None, False
    try:
        candidates, youtube_ok = collect_further(
            listenbrainz, names, known, further_seeds, artist_info
        )
        shown = {names.key(c.name) for c in netease_top}
        ranked = rank(
            {k: c for k, c in candidates.items() if k not in shown},
            limit=len(candidates),
        )
        shown_ids = known_ids | {c.netease_id for c in netease_top if c.netease_id}
        further_top = finish_column(
            netease,
            resolve_on_netease(netease, names, known, ranked, skip_ids=shown_ids),
        )
    except Exception as exc:
        further_error = f"{type(exc).__name__}: {exc}"
        log(f"further failed: {further_error}")
    finally:
        write_json(artists_path, artist_info)

    for c in netease_top + further_top:
        key = names.key(c.name)
        c.seen_before = history.get(key, week) != week
        history.setdefault(key, week)
    write_json(history_path, history, indent=0)

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
        netease_source,
        seed_mix,
    )
    (args.out / f"{week}.html").write_text(page)
    (args.out / "index.html").write_text(page)
    log(f"wrote {args.out / 'index.html'}")
    return 1 if netease_error and further_error else 0


if __name__ == "__main__":
    sys.exit(main())
