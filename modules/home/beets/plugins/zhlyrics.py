"""Make the lyrics plugin work with bilingual Chinese tags.

Deezer tags Chinese releases bilingually ("Kidney 腰乐队", "A Love Letter 情书"),
while LRCLib usually lists only the Chinese name, often in Traditional script
("Kidney (腰)", "情書"), and its search does not fold Simplified and Traditional
characters. The stock artist/title search therefore never matches.

When the stock lookup finds nothing for a Chinese track, this plugin searches
LRCLib by the Chinese half of the title in Traditional and Simplified script,
first together with each form of the artist name, then by title alone (common
titles like "情書" return too many songs for the right one to make the cut
otherwise). It keeps candidates whose artist matches any half of the tagged
artist and whose duration fits. Found lyrics are converted to one script so
they match the library's tags.
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


def unique(values: list[str]) -> list[str]:
    return list(dict.fromkeys(v.strip() for v in values if v.strip()))


class ZhLyricsPlugin(BeetsPlugin):
    def __init__(self) -> None:
        super().__init__()
        self.config.add({"convert": "t2s"})

        self.s2t = opencc.OpenCC("s2t")
        self.t2s = opencc.OpenCC("t2s")
        convert = self.config["convert"].get()
        self.converter = opencc.OpenCC(convert) if convert else None

        stock = lyrics.LyricsPlugin.find_lyrics

        def find_lyrics(plugin: lyrics.LyricsPlugin, item) -> Lyrics | None:
            found = stock(plugin, item)
            if found is None and CJK.search(item.title):
                found = self.search_lrclib(plugin, item)
            return self.convert(found)

        lyrics.LyricsPlugin.find_lyrics = find_lyrics

    def normalize(self, name: str) -> str:
        return self.t2s.convert(name).casefold()

    def artist_names(self, artist: str) -> set[str]:
        """Return normalized forms an LRCLib artist name may contain."""
        names = {self.normalize(artist)}
        if match := BILINGUAL.match(artist.strip()):
            cjk = self.normalize(match["cjk"])
            names |= {self.normalize(match["latin"]), cjk, BAND_SUFFIX.sub("", cjk)}
        return {n.strip() for n in names if n.strip()}

    def artist_queries(self, artist: str) -> list[str]:
        """Return artist spellings to send to LRCLib, most likely first."""
        match = BILINGUAL.match(artist.strip())
        if not match:
            return unique([artist, self.s2t.convert(artist)])
        cjk = match["cjk"]
        return unique(
            [
                match["latin"],
                self.s2t.convert(BAND_SUFFIX.sub("", cjk)),
                self.s2t.convert(cjk),
                cjk,
            ]
        )

    def title_queries(self, title: str) -> list[str]:
        match = BILINGUAL.match(title.strip())
        cjk = match["cjk"] if match else title
        traditional = self.s2t.convert(cjk)
        return unique([traditional, cjk])

    def search_lrclib(self, plugin: lyrics.LyricsPlugin, item) -> Lyrics | None:
        backend = next(
            (b for b in plugin.backends if isinstance(b, lyrics.LRCLib)), None
        )
        if backend is None:
            return None

        wanted = self.artist_names(item.artist)
        length = round(item.length)
        titles = self.title_queries(item.title)
        queries = [
            {"artist_name": artist, "track_name": title}
            for artist in self.artist_queries(item.artist)
            for title in titles
        ] + [{"track_name": title} for title in titles]

        for params in queries:
            with backend.handle_request():
                results = backend.get_json(backend.SEARCH_URL, params=params)
                candidates = [
                    lyrics.LRCLyrics.make(result, length)
                    for result in results
                    if any(
                        name in self.normalize(result["artistName"])
                        for name in wanted
                    )
                ]
                if best := backend.pick_best_match(candidates):
                    self._log.info("found {} via {}", item, params)
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
