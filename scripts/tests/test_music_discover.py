import contextlib
import datetime as dt
import importlib.util
import io
import random
import sqlite3
import sys
import tempfile
import unittest
import urllib.error
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "music-discover.py"
spec = importlib.util.spec_from_file_location("music_discover", SCRIPT)
discover = importlib.util.module_from_spec(spec)
# dataclasses resolve string annotations through sys.modules.
sys.modules[spec.name] = discover
spec.loader.exec_module(discover)

NOW = dt.datetime(2026, 10, 1, 12, 0)


def ms(days_ago: int) -> int:
    return int((NOW - dt.timedelta(days=days_ago)).timestamp() * 1000)


def song(song_id, artist, days_ago=0, name=None):
    return discover.Song(
        song_id, name or f"song{song_id}", [(song_id * 10, artist)], ms(days_ago)
    )


class NamesTest(unittest.TestCase):
    def setUp(self):
        self.names = discover.Names()

    def test_bilingual_name_yields_both_halves_and_band_stem(self):
        keys = self.names.keys("Kidney 腰乐队")
        self.assertIn("kidney", keys)
        self.assertIn("腰乐队", keys)
        # "腰" alone is too short to be used as a match key.
        self.assertNotIn("腰", keys)

    def test_chinese_first_bilingual_name(self):
        keys = self.names.keys("田馥甄 Hebe Tien")
        self.assertIn("田馥甄", keys)
        self.assertIn("hebetien", keys)

    def test_spacing_and_case_are_ignored(self):
        self.assertEqual(
            self.names.key("Black Country, New Road"),
            self.names.key("black country new road"),
        )

    def test_known_artist_matches_by_any_half(self):
        known = discover.known_artists(self.names, [song(1, "Kidney 腰乐队")], [])
        self.assertTrue(discover.is_known(self.names, "Kidney", known))
        self.assertTrue(discover.is_known(self.names, "腰乐队", known))
        self.assertFalse(discover.is_known(self.names, "寸铁", known))

    def test_search_spellings_try_latin_half_first(self):
        self.assertEqual(
            discover.Names.spellings("Kidney 腰乐队"),
            ["Kidney", "腰乐队", "Kidney 腰乐队"],
        )
        self.assertEqual(discover.Names.spellings("椎名林檎"), ["椎名林檎"])

    def test_library_artists_are_known(self):
        known = discover.known_artists(self.names, [], ["温格华生"])
        self.assertTrue(discover.is_known(self.names, "温格华生", known))


class SeedTest(unittest.TestCase):
    def test_one_song_per_artist(self):
        songs = [song(i, "Pink Floyd", 1) for i in range(50)] + [song(100, "Yes", 1)]
        seeds = discover.pick_seeds(songs, NOW, random.Random(0), (40, 20))
        self.assertEqual(sorted(s.artist for s in seeds), ["Pink Floyd", "Yes"])

    def test_recent_quota_then_broad_quota(self):
        recent = [song(i, f"recent{i}", 10) for i in range(100)]
        old = [song(1000 + i, f"old{i}", 400) for i in range(100)]
        seeds = discover.pick_seeds(recent + old, NOW, random.Random(0), (40, 20))
        self.assertEqual(len(seeds), 60)
        self.assertGreaterEqual(sum(s.artist.startswith("recent") for s in seeds), 40)
        self.assertTrue(any(s.artist.startswith("old") for s in seeds))

    def test_same_week_same_seeds(self):
        songs = [song(i, f"a{i}", i % 200) for i in range(300)]
        a = discover.pick_seeds(songs, NOW, random.Random("2026-W40"), (40, 20))
        b = discover.pick_seeds(songs, NOW, random.Random("2026-W40"), (40, 20))
        self.assertEqual([s.id for s in a], [s.id for s in b])


class RankTest(unittest.TestCase):
    def test_distinct_seeds_outrank_repeated_tracks(self):
        wide = discover.Candidate("寸铁", "u")
        narrow = discover.Candidate("某人", "u")
        for i in range(3):
            wide.add(song(i, f"s{i}"), discover.Track("t", "u"))
        for i in range(5):
            narrow.add(song(0, "s0"), discover.Track(f"t{i}", "u"))
        ranked = discover.rank({"a": narrow, "b": wide})
        self.assertEqual([c.name for c in ranked], ["寸铁", "某人"])
        self.assertEqual((wide.score, narrow.score), (3, 1))

    def test_single_seed_artists_only_pad_short_lists(self):
        strong = {}
        for i in range(10):
            c = discover.Candidate(f"strong{i}", "u")
            c.add(song(1, "a"))
            c.add(song(2, "b"))
            strong[c.name] = c
        weak = {f"weak{i}": discover.Candidate(f"weak{i}", "u") for i in range(10)}
        for c in weak.values():
            c.add(song(3, "c"))
        self.assertEqual(len(discover.rank({**strong, **weak}, 20, 8)), 10)
        self.assertEqual(
            [c.name for c in discover.rank({"s": strong["strong0"], **weak}, 20, 3)],
            ["strong0", "weak0", "weak1"],
        )

    def test_limit(self):
        candidates = {}
        for i in range(50):
            c = candidates[str(i)] = discover.Candidate(str(i), "u")
            c.add(song(1, "a"))
            c.add(song(2, "b"))
        self.assertEqual(len(discover.rank(candidates, 20)), 20)


class RenderTest(unittest.TestCase):
    def test_escapes_and_tags(self):
        c = discover.Candidate("<b>x</b>", "https://example/?a=1&b=2")
        c.add(song(1, "腰乐队", name="不是情书"), discover.Track("t<1>", "https://t"))
        c.on_netease = False
        c.seen_before = True
        page = discover.render(NOW, 2229, [], [c])
        self.assertIn("&lt;b&gt;x&lt;/b&gt;", page)
        self.assertIn("a=1&amp;b=2", page)
        self.assertIn("网易云无", page)
        self.assertIn("已推过", page)
        self.assertIn("腰乐队《不是情书》", page)

    def test_column_error_is_shown(self):
        page = discover.render(NOW, 1, [], [], further_error="KeyError: x")
        self.assertIn("这一栏本周没有生成：KeyError: x", page)

    def test_youtube_outage_is_noted(self):
        self.assertIn(
            "YouTube Music 本周不可用",
            discover.render(NOW, 1, [], [], youtube_ok=False),
        )

    def test_artist_without_tracks_links_to_search(self):
        c = discover.Candidate("大象體操", "u")
        c.add(song(1, "Chinese Football"))
        page = discover.render(NOW, 1, [], [c])
        self.assertIn("在 YouTube Music 搜索", page)


class RetryTest(unittest.TestCase):
    def http_error(self, code):
        return urllib.error.HTTPError("u", code, "x", {}, None)

    @patch.object(discover.time, "sleep")
    def test_retries_when_service_says_slow_down(self, _sleep):
        responses = [self.http_error(503), io.BytesIO(b'{"ok": 1}')]

        def urlopen(*_args, **_kwargs):
            r = responses.pop(0)
            if isinstance(r, Exception):
                raise r
            return r

        with patch.object(discover.urllib.request, "urlopen", urlopen):
            self.assertEqual(discover.Paced().fetch_json("https://x"), {"ok": 1})

    @patch.object(discover.time, "sleep")
    def test_other_errors_are_not_retried(self, _sleep):
        calls = []

        def urlopen(*_args, **_kwargs):
            calls.append(1)
            raise self.http_error(404)

        with patch.object(discover.urllib.request, "urlopen", urlopen):
            with self.assertRaises(urllib.error.HTTPError) as raised:
                discover.Paced().fetch_json("https://x")
            raised.exception.close()
        self.assertEqual(len(calls), 1)


class FakeNetEase(discover.NetEase):
    """Answers NetEase API calls from a {(path, s or id): payload} table."""

    def __init__(self, answers):
        super().__init__()
        self.answers = answers

    def get(self, path, **params):
        return self.answers.get((path, params.get("s", params.get("id"))), {})


SEARCH = "/api/search/get/web"
TOP = "/api/artist/top/song"


class NetEaseResolveTest(unittest.TestCase):
    def setUp(self):
        self.names = discover.Names()

    def test_alias_match(self):
        netease = FakeNetEase(
            {
                (SEARCH, "Hebe Tien"): {
                    "result": {
                        "artists": [
                            {"id": 9548, "name": "田馥甄", "alias": ["Hebe Tien"]}
                        ]
                    }
                }
            }
        )
        self.assertEqual(
            netease.find_artist("Hebe Tien", [], self.names), (9548, "田馥甄")
        )

    def test_unrelated_top_hit_is_rejected(self):
        netease = FakeNetEase(
            {
                (SEARCH, "Björk"): {
                    "result": {"artists": [{"id": 1, "name": "Jon Björk"}]}
                }
            }
        )
        self.assertIsNone(netease.find_artist("Björk", [], self.names))

    def test_song_title_fallback(self):
        netease = FakeNetEase(
            {
                (SEARCH, "遇见"): {
                    "result": {
                        "songs": [
                            {"name": "遇见", "artists": [{"id": 2, "name": "孙燕姿"}]}
                        ]
                    }
                }
            }
        )
        self.assertEqual(
            netease.find_artist("Sun Yanzi", ["遇见"], self.names), (2, "孙燕姿")
        )

    def test_resolution_renames_flags_and_drops_known(self):
        netease = FakeNetEase(
            {
                (SEARCH, "Hebe Tien"): {
                    "result": {
                        "artists": [
                            {"id": 9548, "name": "田馥甄", "alias": ["Hebe Tien"]}
                        ]
                    }
                },
                (SEARCH, "Yo La Tengo"): {
                    "result": {"artists": [{"id": 3, "name": "Yo La Tengo"}]}
                },
                (TOP, 3): {"songs": [{"id": 30, "name": "Autumn Sweater"}]},
            }
        )
        known = discover.known_artists(self.names, [song(1, "田馥甄")], [])
        ranked = [
            discover.Candidate(n, "u")
            for n in ("Hebe Tien", "Yo La Tengo", "Nobody Here")
        ]
        kept = discover.resolve_on_netease(netease, self.names, known, ranked)
        self.assertEqual([c.name for c in kept], ["Yo La Tengo", "Nobody Here"])
        self.assertTrue(kept[0].on_netease)
        self.assertEqual(kept[0].tracks[0].title, "Autumn Sweater")
        self.assertIs(kept[1].on_netease, False)


class CircuitBreakerTest(unittest.TestCase):
    @patch.object(discover.time, "sleep")
    def test_gives_up_for_the_rest_of_the_run(self, _sleep):
        netease = discover.NetEase()
        calls = []

        def fetch_json(url, headers=None):
            calls.append(url)
            return {"code": 405}

        netease.fetch_json = fetch_json
        with self.assertRaises(discover.RateLimited):
            netease.get("/api/a")
        tries = len(calls)
        with self.assertRaises(discover.RateLimited):
            netease.get("/api/b")
        self.assertEqual(len(calls), tries)

    def test_partial_netease_column_is_kept(self):
        class Flaky:
            def __init__(self):
                self.n = 0

            def similar(self, song_id):
                self.n += 1
                if self.n > 1:
                    raise discover.RateLimited("x")
                return [discover.Song(9, "新歌", [(90, "寸铁")])]

        names = discover.Names()
        found = discover.collect_netease(
            Flaky(), names, set(), [song(1, "a"), song(2, "b")]
        )
        self.assertEqual([c.name for c in found.values()], ["寸铁"])


class LibraryTest(unittest.TestCase):
    def test_reads_artists_and_album_artists(self):
        with tempfile.TemporaryDirectory() as tmp:
            db = Path(tmp) / "library.db"
            with contextlib.closing(sqlite3.connect(db)) as conn, conn:
                conn.execute("create table items (artist text, albumartist text)")
                conn.execute("insert into items values ('a', 'b'), ('', 'b')")
            self.assertEqual(sorted(discover.library_artists(db)), ["a", "b"])

    def test_missing_db(self):
        self.assertEqual(discover.library_artists(Path("/nonexistent/library.db")), [])


if __name__ == "__main__":
    unittest.main()
