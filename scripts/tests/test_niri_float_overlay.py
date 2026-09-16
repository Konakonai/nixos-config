import importlib.util
import io
import ctypes
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch, Mock

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

    def shape_event_session(self, events):
        session = overlay.ShapeSession()
        session.dpy = 1
        session.target = 42
        session.mask = 7
        session.shape_event = 99
        session.x11 = Mock()
        session.x11.XPending.side_effect = lambda dpy: len(events)
        def next_event(dpy, pointer):
            event = events.pop(0)
            ctypes.memmove(pointer, ctypes.byref(event), ctypes.sizeof(event))
        session.x11.XNextEvent.side_effect = next_event
        session.restamp = Mock(return_value=True)
        return session

    def test_wine_clearing_input_is_repaired_without_waiting_for_frame(self):
        event = overlay.XShapeEvent(type=99, window=42, kind=2,
                                    serial=10, shaped=1, width=0, height=0)
        session = self.shape_event_session([event])
        session.wait(0)
        session.restamp.assert_called_once()

    def test_transparent_frame_does_not_trigger_shape_feedback_loop(self):
        event = overlay.XShapeEvent(type=99, window=42, kind=2,
                                    serial=10, shaped=1, width=0, height=0)
        session = self.shape_event_session([event])
        session.own_shapes.add(10)
        session.wait(0)
        session.restamp.assert_not_called()
        self.assertEqual(session.own_shapes, set())

    def test_unrelated_windows_do_not_trigger_repair(self):
        event = overlay.XShapeEvent(type=99, window=43, kind=2,
                                    serial=10, shaped=0)
        session = self.shape_event_session([event])
        session.wait(0)
        session.restamp.assert_not_called()

    def test_x_error_invalidates_resources_and_allows_rediscovery(self):
        session = overlay.ShapeSession()
        session.dpy = 1
        session.target, session.mask, session.picture = 42, 7, 8
        session.x11, session.render = Mock(), Mock()
        session._error(None, None)
        self.assertFalse(session.restamp())
        session.reset()
        session.render.XRenderFreePicture.assert_called_once_with(1, 8)
        session.x11.XFreePixmap.assert_called_once_with(1, 7)
        self.assertEqual(session.target, 0)
        self.assertFalse(session.failed)

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
