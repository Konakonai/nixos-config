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
