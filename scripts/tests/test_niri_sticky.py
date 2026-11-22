import importlib.util
import json
from pathlib import Path
import socket
import tempfile
import threading
import time
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "niri-sticky.py"
spec = importlib.util.spec_from_file_location("niri_sticky", SCRIPT)
sticky = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sticky)


def ws(id, output="eDP-1", active=False, focused=False):
    return {"id": id, "output": output, "is_active": active, "is_focused": focused}


def win(id, app_id="app", title="Title", workspace_id=1, is_floating=True):
    return {
        "id": id,
        "app_id": app_id,
        "title": title,
        "workspace_id": workspace_id,
        "is_floating": is_floating,
    }


class NiriStickyTests(unittest.TestCase):
    def test_auto_rules_match_expected_overlays(self):
        state = sticky.StickyState()
        self.assertTrue(state.is_auto_sticky(win(1, "zen-beta", "Picture-in-Picture")))
        self.assertTrue(state.is_auto_sticky(win(2, "zen-beta", "画中画")))
        self.assertTrue(
            state.is_auto_sticky(win(3, "top.imsyy.splayer_next", "Dynamic Island"))
        )
        self.assertTrue(
            state.is_auto_sticky(
                win(4, "SPlayer-Next", "SPlayer-Next - Desktop Lyric")
            )
        )
        self.assertTrue(state.is_auto_sticky(win(5, "nectarlink", "Nectar 岛 - PiP")))
        self.assertTrue(state.is_auto_sticky(win(6, "nectarlink", "NectarLink 收纳架")))

        # Main app windows and phone mirror windows are NOT auto-sticky (pin with Mod+P).
        self.assertFalse(state.is_auto_sticky(win(7, "top.imsyy.splayer_next", "SPlayer-Next")))
        self.assertFalse(state.is_auto_sticky(win(8, "nectarlink", "NectarLink")))
        self.assertFalse(state.is_auto_sticky(win(9, "nectarlink", "Brave · Phone")))

    def test_follows_workspace_switch_on_same_output_only(self):
        state = sticky.StickyState()
        state.apply_event(
            {
                "WorkspacesChanged": {
                    "workspaces": [
                        ws(1, "eDP-1", active=True, focused=True),
                        ws(2, "eDP-1", active=False),
                        ws(3, "DP-7", active=True),
                        ws(4, "DP-7", active=False),
                    ]
                }
            }
        )
        state.apply_event(
            {
                "WindowsChanged": {
                    "windows": [
                        win(10, "zen-beta", "Picture-in-Picture", workspace_id=1, is_floating=True),
                        win(11, "nectarlink", "Brave · Phone", workspace_id=3, is_floating=True),
                        # Tiled PiP must never be yanked across workspaces.
                        win(12, "zen-beta", "Picture-in-Picture", workspace_id=1, is_floating=False),
                    ]
                }
            }
        )
        # Manually pin the phone app window on DP-7.
        status, needs_float = state.set_pinned(state.windows[11], "toggle")
        self.assertEqual((status, needs_float), ("pinned", False))

        # Switch workspace on eDP-1: only window 10 follows; window 11 stays on DP-7.
        moves = state.apply_event({"WorkspaceActivated": {"id": 2, "focused": True}})
        self.assertEqual(moves, [(10, 2)])

        # Focusing DP-7's already-active workspace does not disturb eDP-1 or move 11.
        state.apply_event(
            {"WindowOpenedOrChanged": {"window": win(10, "zen-beta", "Picture-in-Picture", workspace_id=2)}}
        )
        moves = state.apply_event({"WorkspaceActivated": {"id": 3, "focused": True}})
        self.assertEqual(moves, [])

        # Switching workspace on DP-7 brings pinned window 11 along.
        moves = state.apply_event({"WorkspaceActivated": {"id": 4, "focused": True}})
        self.assertEqual(moves, [(11, 4)])

    def test_overview_defers_moves_until_closed(self):
        state = sticky.StickyState()
        state.apply_event(
            {
                "WorkspacesChanged": {
                    "workspaces": [ws(1, "eDP-1", active=True), ws(2, "eDP-1", active=False)]
                }
            }
        )
        state.apply_event(
            {
                "WindowsChanged": {
                    "windows": [
                        win(20, "top.imsyy.splayer_next", "Dynamic Island", workspace_id=1)
                    ]
                }
            }
        )
        self.assertEqual(state.apply_event({"OverviewOpenedOrClosed": {"is_open": True}}), [])
        self.assertEqual(state.apply_event({"WorkspaceActivated": {"id": 2, "focused": True}}), [])
        self.assertEqual(
            state.apply_event({"OverviewOpenedOrClosed": {"is_open": False}}),
            [(20, 2)],
        )

    def test_toggle_auto_floats_tiled_window_and_unpins_auto_sticky(self):
        state = sticky.StickyState()
        tiled = win(30, "kitty", "shell", workspace_id=1, is_floating=False)
        self.assertEqual(state.set_pinned(tiled, "toggle"), ("pinned", True))
        self.assertTrue(state.is_sticky(state.windows[30]))

        # Explicitly tiling a manually pinned window clears its pin.
        state.apply_event({"WindowOpenedOrChanged": {"window": tiled}})
        self.assertNotIn(30, state.pinned_ids)

        # Auto-sticky window can be manually unpinned and re-pinned.
        pip = win(31, "zen-beta", "Picture-in-Picture", workspace_id=1, is_floating=True)
        state.apply_event({"WindowOpenedOrChanged": {"window": pip}})
        self.assertTrue(state.is_sticky(pip))
        self.assertEqual(state.set_pinned(pip, "toggle"), ("unpinned", False))
        self.assertFalse(state.is_sticky(pip))
        self.assertEqual(state.set_pinned(pip, "toggle"), ("pinned", False))
        self.assertTrue(state.is_sticky(pip))

        # Closing cleans up tracking sets.
        state.apply_event({"WindowClosed": {"id": 31}})
        self.assertNotIn(31, state.pinned_ids)
        self.assertNotIn(31, state.unpinned_auto_ids)

    def test_daemon_socket_roundtrip_pin_and_follow(self):
        with tempfile.TemporaryDirectory() as td:
            niri_sock = Path(td) / "niri.sock"
            ctl_sock = Path(td) / "sticky.sock"

            actions = []
            stream_conn_ready = threading.Event()
            stream_holder = []

            server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            server.bind(str(niri_sock))
            server.listen(8)

            def fake_niri():
                while True:
                    try:
                        conn, _ = server.accept()
                    except OSError:
                        break
                    line = conn.makefile("r", encoding="utf-8").readline()
                    if not line:
                        conn.close()
                        continue
                    req = json.loads(line)
                    if req == "EventStream":
                        conn.sendall(b'{"Ok":"Handled"}\n')
                        conn.sendall(
                            (
                                json.dumps(
                                    {
                                        "WorkspacesChanged": {
                                            "workspaces": [
                                                ws(1, "eDP-1", active=True, focused=True),
                                                ws(2, "eDP-1", active=False),
                                            ]
                                        }
                                    }
                                )
                                + "\n"
                            ).encode()
                        )
                        conn.sendall(
                            (
                                json.dumps(
                                    {
                                        "WindowsChanged": {
                                            "windows": [
                                                win(50, "kitty", "shell", workspace_id=1, is_floating=False)
                                            ]
                                        }
                                    }
                                )
                                + "\n"
                            ).encode()
                        )
                        stream_holder.append(conn)
                        stream_conn_ready.set()
                    elif req == "FocusedWindow":
                        conn.sendall(
                            (
                                json.dumps(
                                    {
                                        "Ok": {
                                            "FocusedWindow": win(
                                                50, "kitty", "shell", workspace_id=1, is_floating=False
                                            )
                                        }
                                    }
                                )
                                + "\n"
                            ).encode()
                        )
                        conn.close()
                    elif isinstance(req, dict) and "Action" in req:
                        actions.append(req["Action"])
                        conn.sendall(b'{"Ok":"Handled"}\n')
                        conn.close()

            niri_thread = threading.Thread(target=fake_niri, daemon=True)
            niri_thread.start()

            daemon_thread = threading.Thread(
                target=sticky.run_daemon, args=(str(niri_sock), ctl_sock), daemon=True
            )
            daemon_thread.start()

            self.assertTrue(stream_conn_ready.wait(timeout=3.0))
            for _ in range(50):
                if ctl_sock.exists():
                    break
                time.sleep(0.02)

            # Toggle pin on tiled window 50 -> floats and pins it.
            rc = sticky.send_control_command(ctl_sock, "toggle", osd=False)
            self.assertEqual(rc, 0)

            # Activate workspace 2 -> daemon moves window 50 with focus=False.
            stream_holder[0].sendall(
                (json.dumps({"WorkspaceActivated": {"id": 2, "focused": True}}) + "\n").encode()
            )
            for _ in range(50):
                if len(actions) >= 2:
                    break
                time.sleep(0.02)

            stream_holder[0].close()
            server.close()
            daemon_thread.join(timeout=3.0)

            self.assertEqual(actions[0], {"MoveWindowToFloating": {"id": 50}})
            self.assertEqual(
                actions[1],
                {
                    "MoveWindowToWorkspace": {
                        "window_id": 50,
                        "reference": {"Id": 2},
                        "focus": False,
                    }
                },
            )


if __name__ == "__main__":
    unittest.main()
