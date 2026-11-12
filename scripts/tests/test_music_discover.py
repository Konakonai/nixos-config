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
    def pick(self, songs, total=60, genres=None, rng=0):
        return discover.pick_seeds(songs, NOW, random.Random(rng), total, genres or {})

    def test_one_song_per_artist(self):
        songs = [song(i, "Pink Floyd", 1) for i in range(50)] + [song(100, "Yes", 1)]
        seeds, _ = self.pick(songs)
        self.assertEqual(sorted(s.artist for s in seeds), ["Pink Floyd", "Yes"])

    def test_big_genre_does_not_drown_small_ones(self):
        songs = [song(i, f"electro{i}", 10) for i in range(100)]
        songs += [song(1000 + i, f"jazz{i}", 10) for i in range(4)]
        genres = {
            s.artist: "电子" if s.artist.startswith("electro") else "爵士/灵魂"
            for s in songs
        }
        seeds, quotas = self.pick(songs, total=20, genres=genres)
        self.assertEqual(len(seeds), 20)
        # sqrt(100)=10 vs sqrt(4)=2 -> jazz gets 1/6 of the seats, not 4/104.
        self.assertEqual(quotas, {"电子": 17, "爵士/灵魂": 3})

    def test_recent_artists_first_within_a_bucket(self):
        songs = [song(i, f"recent{i}", 10) for i in range(10)]
        songs += [song(100 + i, f"old{i}", 400) for i in range(10)]
        seeds, _ = self.pick(songs, total=10)
        self.assertTrue(all(s.artist.startswith("recent") for s in seeds))

    def test_same_week_same_seeds(self):
        songs = [song(i, f"a{i}", i % 200) for i in range(300)]
        a, _ = self.pick(songs, rng="2026-W40")
        b, _ = self.pick(songs, rng="2026-W40")
        self.assertEqual([s.id for s in a], [s.id for s in b])


class GenreTest(unittest.TestCase):
    def test_most_voted_matching_tag_wins(self):
        self.assertEqual(
            discover.genre_of(["japan", "rock", "jazz"], "椎名林檎"), "摇滚"
        )
        self.assertEqual(
            discover.genre_of(["trip hop", "electronic"], "Portishead"), "电子"
        )
        self.assertEqual(discover.genre_of(["indie pop"], "x"), "流行")
        self.assertEqual(discover.genre_of(["folk rock"], "x"), "民谣")

    def test_untagged_artists_bucket_by_script(self):
        self.assertEqual(discover.genre_of([], "腰乐队"), "华语（无标签）")
        self.assertEqual(discover.genre_of([], "フィッシュマンズ"), "日语（无标签）")
        self.assertEqual(discover.genre_of(["seen live"], "Someone"), "其他（无标签）")

    def test_quotas_never_exceed_bucket_size(self):
        self.assertEqual(discover.bucket_quotas({"a": 1, "b": 1}, 10), {"a": 1, "b": 1})


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
    def test_retries_dropped_connections(self, _sleep):
        responses = [urllib.error.URLError("EOF"), io.BytesIO(b"[]")]

        def urlopen(*_args, **_kwargs):
            r = responses.pop(0)
            if isinstance(r, Exception):
                raise r
            return r

        with patch.object(discover.urllib.request, "urlopen", urlopen):
            self.assertEqual(discover.Paced().fetch_json("https://x"), [])

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
        self.assertEqual(kept[0].netease_id, 3)
        self.assertIs(kept[1].on_netease, False)

    def test_resolved_artist_shown_on_the_left_is_dropped(self):
        hebe = {
            "result": {
                "artists": [
                    {"id": 9548, "name": "田馥甄", "alias": ["Hebe Tien", "Tian Fuzhen"]}
                ]
            }
        }
        netease = FakeNetEase(
            {
                (SEARCH, "Hebe Tien"): hebe,
                (SEARCH, "Tian Fuzhen"): hebe,
                (SEARCH, "Liked Alias"): {
                    "result": {"artists": [{"id": 7, "name": "Liked Alias"}]}
                },
                (SEARCH, "Yo La Tengo"): {
                    "result": {"artists": [{"id": 3, "name": "Yo La Tengo"}]}
                },
            }
        )
        ranked = [
            discover.Candidate(n, "u")
            for n in ("Hebe Tien", "Liked Alias", "Yo La Tengo")
        ]
        kept = discover.resolve_on_netease(
            netease, self.names, set(), ranked, skip_ids={9548, 7}
        )
        self.assertEqual([c.name for c in kept], ["Yo La Tengo"])

        # Two spellings of one NetEase artist are kept once.
        ranked = [discover.Candidate(n, "u") for n in ("Hebe Tien", "Tian Fuzhen")]
        kept = discover.resolve_on_netease(netease, self.names, set(), ranked)
        self.assertEqual([c.netease_id for c in kept], [9548])


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


class LoggedInTest(unittest.TestCase):
    def test_similar_artists_mode(self):
        class Fake:
            def similar_artists(self, artist_id):
                return [(7, "寸铁"), (8, "腰乐队")]

        names = discover.Names()
        known = discover.known_artists(names, [song(1, "腰乐队")], [])
        seeds = [song(1, "腰乐队"), song(2, "Kidney")]
        found = discover.collect_netease(Fake(), names, known, seeds, by_artist=True)
        (candidate,) = found.values()
        self.assertEqual(
            (candidate.name, candidate.netease_id, candidate.score), ("寸铁", 7, 2)
        )

    def test_page_names_the_netease_source(self):
        page = discover.render(
            NOW,
            1,
            [],
            [],
            netease_source="网易云「相似歌曲」（登录 cookie 已失效，按未登录处理）",
        )
        self.assertIn("登录 cookie 已失效", page)


class FinishColumnTest(unittest.TestCase):
    def test_hot_artists_go_last_and_followed_ones_go(self):
        class Fake:
            fan_counts = {
                1: (19_022_530, False),
                2: (224_818, False),
                3: (50_000, True),
            }

            def fans(self, artist_id):
                return self.fan_counts[artist_id]

            def top_tracks(self, artist_id):
                return [discover.Track(f"hit{artist_id}", "u")]

        ranked = []
        for artist_id, name in (
            (1, "周杰伦"),
            (2, "寸铁"),
            (3, "已关注"),
            (None, "Björk"),
        ):
            c = discover.Candidate(name, "u")
            c.netease_id = artist_id
            ranked.append(c)
        shown = discover.finish_column(Fake(), ranked)
        self.assertEqual([c.name for c in shown], ["寸铁", "Björk", "周杰伦"])
        self.assertTrue(shown[-1].hot)
        self.assertEqual(shown[0].tracks[0].title, "hit2")

    def test_fans_are_shown_in_wan(self):
        self.assertEqual(discover.format_fans(19_022_530), "1902万")
        self.assertEqual(discover.format_fans(224_818), "22.5万")
        self.assertEqual(discover.format_fans(812), "812")


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

    def test_path_with_uri_characters(self):
        with tempfile.TemporaryDirectory() as tmp:
            db = Path(tmp) / "a b?#%20" / "library.db"
            db.parent.mkdir()
            with contextlib.closing(sqlite3.connect(db)) as conn, conn:
                conn.execute("create table items (artist text, albumartist text)")
                conn.execute("insert into items values ('a', 'b')")
            self.assertEqual(sorted(discover.library_artists(db)), ["a", "b"])


class WriteJsonTest(unittest.TestCase):
    def test_replaces_file_and_leaves_no_temp_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "songs.json"
            path.write_text('{"old": 1}')
            discover.write_json(path, {"新": [1, 2]})
            self.assertEqual(discover.load_json(path, None), {"新": [1, 2]})
            self.assertEqual([p.name for p in Path(tmp).iterdir()], ["songs.json"])

    def test_failed_write_keeps_old_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "songs.json"
            path.write_text('{"old": 1}')
            with self.assertRaises(TypeError):
                discover.write_json(path, {"bad": object()})
            self.assertEqual(discover.load_json(path, None), {"old": 1})
            self.assertEqual([p.name for p in Path(tmp).iterdir()], ["songs.json"])


class CookieTest(unittest.TestCase):
    def test_prefix_and_whitespace_are_tolerated(self):
        for cookie in ("abc", " abc\n", "MUSIC_U=abc", "  MUSIC_U= abc \n"):
            self.assertEqual(
                discover.NetEase(cookie).headers["Cookie"], "MUSIC_U=abc", cookie
            )


if __name__ == "__main__":
    unittest.main()
