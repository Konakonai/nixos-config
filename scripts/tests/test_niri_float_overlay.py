import importlib.util
import io
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "niri-float-overlay.py"
spec = importlib.util.spec_from_file_location("niri_float_overlay", SCRIPT)
overlay = importlib.util.module_from_spec(spec)
spec.loader.exec_module(overlay)


def window(id, app_id="", title="", floating=False):
    return {
        "id": id,
        "app_id": app_id,
        "title": title,
        "is_floating": floating,
    }


class NiriFloatOverlayTests(unittest.TestCase):
    def test_niri_socket_uses_newest_runtime_socket(self, tmp_path=None):
        import tempfile
        import os
        runtime = Path(tempfile.mkdtemp())
        older = runtime / "niri.wayland-1.1.sock"
        newer = runtime / "niri.wayland-1.2.sock"
        older.write_text("")
        newer.write_text("")
        os.utime(older, (1, 1))
        os.utime(newer, (2, 2))
        env = dict(os.environ)
        env.pop("NIRI_SOCKET", None)
        env["XDG_RUNTIME_DIR"] = str(runtime)
        with patch.dict(os.environ, env, clear=True):
            self.assertEqual(overlay.niri_socket(), str(newer))

    def test_clickable_rect_is_a_small_box_around_the_pet(self):
        # Measured pet+HUD extent on a 3840x2160 overlay was x 2440..3212,
        # y 732..1500. The rect must contain that and stay far away from the
        # near-fullscreen box this used to stamp.
        x, y, w, h = overlay.clickable_rect(3840, 2160)
        self.assertLessEqual(x, 2440)
        self.assertLessEqual(y, 732)
        self.assertGreaterEqual(x + w, 3212)
        self.assertGreaterEqual(y + h, 1500)
        self.assertLess((w * h) / (3840 * 2160), 0.20)

    def test_clickable_rect_scales_with_the_window(self):
        x, y, w, h = overlay.clickable_rect(1920, 1080)
        self.assertLess(x + w, 1920)
        self.assertLess(y + h, 1080)

    def test_clickable_rects_include_logical_and_buffer_boxes(self):
        # Scale 1.5: niri reports 2560x1440, X reports 3840x2160. A click on
        # the visible pet at logical (1960, 761) must hit the logical box,
        # while the scaled X event (2940, 1141) must hit the buffer box.
        rects = overlay.clickable_rects(3840, 2160, 2560, 1440)
        self.assertEqual(len(rects), 2)
        buffer, logical = rects
        bx, by, bw, bh = buffer
        lx, ly, lw, lh = logical
        self.assertLessEqual(bx, 2440)
        self.assertGreaterEqual(bx + bw, 3212)
        self.assertLessEqual(lx, 1960)
        self.assertLessEqual(ly, 761)
        self.assertGreaterEqual(lx + lw, 1960)
        self.assertGreaterEqual(ly + lh, 761)
        self.assertLessEqual(bx, 2940)
        self.assertLessEqual(by, 1141)
        self.assertGreaterEqual(bx + bw, 2940)
        self.assertGreaterEqual(by + bh, 1141)
        area = bw * bh + lw * lh
        self.assertLess(area / (3840 * 2160), 0.20)

    def test_clickable_rects_without_logical_size_is_a_single_box(self):
        self.assertEqual(
            overlay.clickable_rects(3840, 2160),
            [overlay.clickable_rect(3840, 2160)],
        )

    def test_inferred_logical_size_uses_output_scale(self):
        with patch.object(overlay, "output_scale", return_value=1.5):
            self.assertEqual(overlay.inferred_logical_size(3840, 2160), (2560, 1440))

    def test_watch_records_overlay_logical_size(self):
        state = overlay.OverlayState()
        events = [
            {"WindowOpenedOrChanged": {"window": {
                "id": 3,
                "app_id": "steam_app_4564320",
                "title": "",
                "is_floating": True,
                "layout": {"window_size": [2560, 1440]},
            }}},
        ]
        stream = io.StringIO("\n".join(map(json.dumps, events)))
        overlay.watch(stream, {}, overlay_state=state)
        self.assertEqual(state.logical_size(), (2560, 1440))

    def test_a_vanished_window_does_not_stop_the_watcher(self):
        events = [
            {"WindowOpenedOrChanged": {"window": window(3, app_id="steam_app_4564320")}},
            {"WindowOpenedOrChanged": {"window": window(4, app_id="YourCoworker.exe")}},
        ]
        stream = io.StringIO("\n".join(map(json.dumps, events)))
        with patch.object(overlay.subprocess, "run") as run:
            overlay.watch(stream, {})
        self.assertEqual([call.args[0][-1] for call in run.call_args_list], ["3", "4"])
        self.assertTrue(all(call.kwargs["check"] is False for call in run.call_args_list))

    def test_late_app_id_floats_once(self):
        events = [
            {"WindowOpenedOrChanged": {"window": window(3, title="")}},
            {"WindowOpenedOrChanged": {"window": window(3, app_id="steam_app_4564320")}},
            {"WindowOpenedOrChanged": {"window": window(3, app_id="steam_app_4564320")}},
        ]
        stream = io.StringIO("\n".join(map(json.dumps, events)))
        with patch.object(overlay.time, "monotonic", side_effect=[0.0, 0.0]), patch.object(overlay.subprocess, "run") as run:
            overlay.watch(stream, {})
        self.assertEqual(run.call_count, 1)
        self.assertEqual(
            run.call_args.args[0][-2:],
            ["--id", "3"],
        )

    def test_retiling_floats_again(self):
        events = [
            {"WindowOpenedOrChanged": {"window": window(3, app_id="steam_app_4564320")}},
            {"WindowOpenedOrChanged": {"window": window(3, app_id="steam_app_4564320", floating=True)}},
            {"WindowOpenedOrChanged": {"window": window(3, app_id="steam_app_4564320")}},
        ]
        stream = io.StringIO("\n".join(map(json.dumps, events)))
        with patch.object(overlay.time, "monotonic", side_effect=[0.0, 1.0]), patch.object(overlay.subprocess, "run") as run:
            overlay.watch(stream, {})
        self.assertEqual(run.call_count, 2)

    def test_already_floating_is_not_touched(self):
        stream = io.StringIO(json.dumps({
            "WindowOpenedOrChanged": {
                "window": window(4, app_id="steam_app_4564320", floating=True),
            },
        }))
        with patch.object(overlay.subprocess, "run") as run:
            overlay.watch(stream, {})
        run.assert_not_called()

    def test_title_match_floats_coworker_window(self):
        stream = io.StringIO(json.dumps({
            "WindowsChanged": {"windows": [
                window(1, title="YourCoworker"),
                window(2, app_id="steam", title="Steam"),
            ]},
        }))
        with patch.object(overlay.time, "monotonic", return_value=0.0), patch.object(overlay.subprocess, "run") as run:
            overlay.watch(stream, {})
        self.assertEqual(run.call_count, 1)
        self.assertEqual(run.call_args.args[0][-2:], ["--id", "1"])


if __name__ == "__main__":
    unittest.main()
