"""Make the lyrics plugin work with bilingual Chinese tags.

Deezer tags Chinese releases bilingually ("Kidney 腰乐队", "A Love Letter 情书"),
while lyrics sites list only the Chinese name, often in Traditional script
("Kidney (腰)", "情書"), and their search does not fold Simplified and
Traditional characters. The stock artist/title search therefore rarely matches.

This plugin:

* registers a `netease` lyrics source (NetEase Cloud Music's unofficial web
  API), which has by far the best coverage of Chinese releases;
* when no source finds anything for a Chinese track, searches LRCLib by the
  Chinese half of the title in Traditional and Simplified script, first with
  each form of the artist name, then by title alone (common titles like "情書"
  return too many songs for the right one to make the cut otherwise);
* converts found lyrics to one script so they match the library's tags.

Candidates are only accepted when their artist matches a half of the tagged
artist and their duration is within the lyrics plugin's tolerance.
"""

from __future__ import annotations

import dataclasses
import re

import opencc
from beets.plugins import BeetsPlugin
from beets.util.lyrics import Lyrics

from beetsplug import lyrics

CJK = re.compile(r"[\u3400-\u9fff\uf900-\ufaff]")
# "Kidney 腰乐队" -> ("Kidney", "腰乐队"); the Chinese half runs from the
# first CJK character to the end, so bracketed suffixes stay attached.
BILINGUAL = re.compile(r"^(?P<latin>[^\u3400-\u9fff]*?)\s*(?P<cjk>[\u3400-\u9fff].*)$")
# Lyrics sites often drop the "band" suffix that streaming services append.
BAND_SUFFIX = re.compile(r"(乐队|乐团|组合)$")
# NetEase prefixes lyrics with timed credit lines ("[00:00.000] 作词 : 刘涛").
CREDIT_LINE = re.compile(
    r"^(\[[\d:.]+\])?\s*(作词|作曲|编曲|制作人|监制|混音|录音|母带|和声|出品)\s*[:：]"
)

S2T = opencc.OpenCC("s2t")
T2S = opencc.OpenCC("t2s")


def unique(values: list[str]) -> list[str]:
    return list(dict.fromkeys(v.strip() for v in values if v.strip()))


def normalize(name: str) -> str:
    return T2S.convert(name).casefold().strip()


def split(name: str) -> tuple[str, str] | None:
    """Split a bilingual name into its Latin and Chinese halves."""
    if match := BILINGUAL.match(name.strip()):
        return match["latin"].strip(), match["cjk"].strip()
    return None


def artist_names(artist: str) -> set[str]:
    """Return normalized forms a lyrics site's artist name may contain."""
    names = {normalize(artist)}
    if halves := split(artist):
        latin, cjk = halves
        names |= {normalize(latin), normalize(cjk), BAND_SUFFIX.sub("", normalize(cjk))}
    return {n for n in names if n}


def artist_matches(candidate: str, wanted: set[str]) -> bool:
    candidate = normalize(candidate)
    return any(name in candidate or candidate in name for name in wanted)


def chinese_title(title: str) -> str:
    halves = split(title)
    return halves[1] if halves else title


def duration_fits(candidate: float, target: float) -> bool:
    tolerance = target * lyrics.LRCLyrics.DURATION_DIFF_TOLERANCE
    return abs(candidate - target) <= tolerance


class NetEase(lyrics.Backend):
    """Fetch lyrics from NetEase Cloud Music."""

    SEARCH_URL = "https://music.163.com/api/search/get/web"
    LYRIC_URL = "https://music.163.com/api/song/lyric"
    HEADERS = {"Referer": "https://music.163.com"}

    def queries(self, artist: str, title: str) -> list[str]:
        halves = split(artist)
        artists = (
            [BAND_SUFFIX.sub("", halves[1]), halves[1], halves[0]] if halves else []
        )
        return unique(
            [f"{chinese_title(title)} {a}" for a in artists] + [f"{title} {artist}"]
        )

    def search(self, artist: str, title: str, length: int) -> list[int]:
        """Return IDs of matching songs, closest duration first."""
        wanted = artist_names(artist)
        titles = {normalize(title), normalize(chinese_title(title))}
        for query in self.queries(artist, title):
            data = self.get_json(
                self.SEARCH_URL,
                params={"s": query, "type": 1, "limit": 20},
                headers=self.HEADERS,
            )
            songs = [
                song
                for song in (data.get("result") or {}).get("songs") or []
                if normalize(song["name"]) in titles
                and any(artist_matches(a["name"], wanted) for a in song["artists"])
                and duration_fits(song["duration"] / 1000, length)
            ]
            if songs:
                songs.sort(key=lambda s: abs(s["duration"] / 1000 - length))
                return [song["id"] for song in songs]
        return []

    def fetch(self, artist: str, title: str, album: str, length: int) -> Lyrics | None:
        # The same recording is often uploaded several times and some uploads
        # have no lyrics, so try a few of the closest matches.
        for song_id in self.search(artist, title, length)[:3]:
            data = self.get_json(
                self.LYRIC_URL,
                params={"id": song_id, "lv": 1, "tv": -1},
                headers=self.HEADERS,
            )
            text = ((data.get("lrc") or {}).get("lyric") or "").strip()
            if not text or "纯音乐" in text:
                continue

            lines = [line for line in text.splitlines() if not CREDIT_LINE.match(line)]
            if not self.config["synced"].get(bool):
                lines = [re.sub(r"^(\[[\d:.]+\])+\s*", "", line) for line in lines]
            return Lyrics(
                "\n".join(lines).strip(),
                self.__class__.name,
                f"https://music.163.com/song?id={song_id}",
            )
        return None


lyrics.BACKEND_BY_NAME[NetEase.name] = NetEase


class ZhLyricsPlugin(BeetsPlugin):
    def __init__(self) -> None:
        super().__init__()
        self.config.add({"convert": "t2s"})
        convert = self.config["convert"].get()
        self.converter = opencc.OpenCC(convert) if convert else None

        stock = lyrics.LyricsPlugin.find_lyrics

        def find_lyrics(plugin: lyrics.LyricsPlugin, item) -> Lyrics | None:
            found = stock(plugin, item)
            if found is None and CJK.search(item.title):
                found = self.search_lrclib(plugin, item)
            return self.convert(found)

        lyrics.LyricsPlugin.find_lyrics = find_lyrics

    def search_lrclib(self, plugin: lyrics.LyricsPlugin, item) -> Lyrics | None:
        backend = next(
            (b for b in plugin.backends if isinstance(b, lyrics.LRCLib)), None
        )
        if backend is None:
            return None

        wanted = artist_names(item.artist)
        length = round(item.length)
        cjk = chinese_title(item.title)
        titles = unique([S2T.convert(cjk), cjk])
        halves = split(item.artist)
        artists = (
            unique(
                [
                    halves[0],
                    S2T.convert(BAND_SUFFIX.sub("", halves[1])),
                    S2T.convert(halves[1]),
                    halves[1],
                ]
            )
            if halves
            else unique([item.artist, S2T.convert(item.artist)])
        )
        queries = [
            {"artist_name": artist, "track_name": title}
            for artist in artists
            for title in titles
        ] + [{"track_name": title} for title in titles]

        for params in queries:
            with backend.handle_request():
                results = backend.get_json(backend.SEARCH_URL, params=params)
                candidates = [
                    lyrics.LRCLyrics.make(result, length)
                    for result in results
                    if artist_matches(result["artistName"], wanted)
                ]
                if best := backend.pick_best_match(candidates):
                    self._log.info("found {} via LRCLib {}", item, params)
                    return Lyrics(
                        best.get_text(plugin.config["synced"].get(bool)),
                        backend.__class__.name,
                        f"{backend.GET_URL}/{best.id}",
                    )
        return None

    def convert(self, found: Lyrics | None) -> Lyrics | None:
        if found is None or self.converter is None or not CJK.search(found.text):
            return found
        return dataclasses.replace(
            found,
            text=self.converter.convert(found.text),
            translations=[self.converter.convert(t) for t in found.translations],
        )
