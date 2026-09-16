import importlib.util
import io
import json
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
    def test_late_app_id_floats_once(self):
        events = [
            {"WindowOpenedOrChanged": {"window": window(3, title="")}},
            {"WindowOpenedOrChanged": {"window": window(3, app_id="steam_app_4564320")}},
            {"WindowOpenedOrChanged": {"window": window(3, app_id="steam_app_4564320")}},
        ]
        stream = io.StringIO("\n".join(map(json.dumps, events)))
        with patch.object(overlay.subprocess, "run") as run:
            overlay.watch(stream, set())
        self.assertEqual(run.call_count, 1)
        self.assertEqual(
            run.call_args.args[0][-2:],
            ["--id", "3"],
        )

    def test_already_floating_is_not_touched(self):
        stream = io.StringIO(json.dumps({
            "WindowOpenedOrChanged": {
                "window": window(4, app_id="steam_app_4564320", floating=True),
            },
        }))
        with patch.object(overlay.subprocess, "run") as run:
            overlay.watch(stream, set())
        run.assert_not_called()

    def test_title_match_floats_coworker_window(self):
        stream = io.StringIO(json.dumps({
            "WindowsChanged": {"windows": [
                window(1, title="YourCoworker"),
                window(2, app_id="steam", title="Steam"),
            ]},
        }))
        with patch.object(overlay.subprocess, "run") as run:
            overlay.watch(stream, set())
        self.assertEqual(run.call_count, 1)
        self.assertEqual(run.call_args.args[0][-2:], ["--id", "1"])


if __name__ == "__main__":
    unittest.main()
