"""Sticky (cross-workspace) floating windows for Niri.

Niri isolates floating windows per workspace and has no native sticky/pin mode.
This script runs two roles:
  - `niri-sticky daemon`: listens to Niri's IPC event stream and moves sticky
    floating windows along with workspace switches on their current monitor
    (`focus: false`, preserving floating position and never stealing focus).
  - `niri-sticky toggle|pin|unpin|list`: talks to the daemon over a local Unix
    socket so a keybind (Mod+P) can pin/unpin any window (auto-floating tiled
    windows when pinning) or override an auto-sticky rule for that window.
"""

from __future__ import annotations

from dataclasses import dataclass
import json
import os
from pathlib import Path
import re
import selectors
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time


@dataclass(frozen=True)
class AutoRule:
    app_id: re.Pattern[str] | None = None
    title: re.Pattern[str] | None = None

    def matches(self, window: dict) -> bool:
        app_id = window.get("app_id") or ""
        title = window.get("title") or ""
        if self.app_id is not None and not self.app_id.search(app_id):
            return False
        if self.title is not None and not self.title.search(title):
            return False
        return True


DEFAULT_AUTO_RULES: tuple[AutoRule, ...] = (
    # Browser Picture-in-Picture (Zen / Firefox / Chromium / Brave).
    AutoRule(title=re.compile(r"^(Picture-in-Picture|画中画)$")),
    # SPlayer-Next Dynamic Island and Desktop Lyric overlays.
    AutoRule(
        app_id=re.compile(r"^(top\.imsyy\.splayer_next|[Ss][Pp]layer-[Nn]ext)$"),
        title=re.compile(r"^(Dynamic Island|SPlayer-Next - Desktop Lyric)$"),
    ),
    # NectarLink Island and Shelf fallback when not running as wlr-layer-shell.
    AutoRule(
        app_id=re.compile(r"^nectarlink$"),
        title=re.compile(r"^(Nectar Island|Nectar 岛|NectarLink (Shelf|收纳架)$)"),
    ),
)


class StickyState:
    """Pure state machine tracking Niri workspaces, windows, and pinned IDs."""

    def __init__(self, auto_rules: tuple[AutoRule, ...] = DEFAULT_AUTO_RULES):
        self.auto_rules = auto_rules
        self.workspaces: dict[int, dict] = {}
        self.active_ws_by_output: dict[str, int] = {}
        self.windows: dict[int, dict] = {}
        self.pinned_ids: set[int] = set()
        self.unpinned_auto_ids: set[int] = set()
        self.overview_open: bool = False

    def is_auto_sticky(self, window: dict) -> bool:
        return any(rule.matches(window) for rule in self.auto_rules)

    def is_sticky(self, window: dict) -> bool:
        if not window.get("is_floating"):
            return False
        wid = window["id"]
        if wid in self.pinned_ids:
            return True
        return self.is_auto_sticky(window) and wid not in self.unpinned_auto_ids

    def sticky_ids(self) -> list[int]:
        return sorted(wid for wid, win in self.windows.items() if self.is_sticky(win))

    def _rebuild_active_workspaces(self) -> None:
        active: dict[str, int] = {}
        for ws in self.workspaces.values():
            output = ws.get("output")
            if output and ws.get("is_active"):
                active[output] = ws["id"]
        self.active_ws_by_output = active

    def pending_moves(self) -> list[tuple[int, int]]:
        """Return (window_id, target_workspace_id) moves needed right now."""
        if self.overview_open:
            return []
        moves: list[tuple[int, int]] = []
        for wid, win in self.windows.items():
            if not self.is_sticky(win):
                continue
            ws_id = win.get("workspace_id")
            if ws_id is None or ws_id not in self.workspaces:
                continue
            output = self.workspaces[ws_id].get("output")
            if not output:
                continue
            target_ws = self.active_ws_by_output.get(output)
            if target_ws is None or target_ws == ws_id:
                continue
            moves.append((wid, target_ws))
        return moves

    def apply_event(self, event: dict) -> list[tuple[int, int]]:
        """Update state from one Niri IPC event and return moves to perform."""
        if "WorkspacesChanged" in event:
            ws_list = event["WorkspacesChanged"]["workspaces"]
            self.workspaces = {ws["id"]: dict(ws) for ws in ws_list}
            self._rebuild_active_workspaces()
            return self.pending_moves()

        if "WorkspaceActivated" in event:
            ws_id = event["WorkspaceActivated"]["id"]
            focused = bool(event["WorkspaceActivated"].get("focused"))
            ws = self.workspaces.get(ws_id)
            if ws is None:
                return []
            output = ws.get("output")
            for other in self.workspaces.values():
                if output and other.get("output") == output:
                    other["is_active"] = other["id"] == ws_id
                if focused:
                    other["is_focused"] = other["id"] == ws_id
            if output:
                self.active_ws_by_output[output] = ws_id
            return self.pending_moves()

        if "WindowsChanged" in event:
            win_list = event["WindowsChanged"]["windows"]
            self.windows = {win["id"]: dict(win) for win in win_list}
            alive = set(self.windows)
            self.pinned_ids &= alive
            self.unpinned_auto_ids &= alive
            return self.pending_moves()

        if "WindowOpenedOrChanged" in event:
            win = dict(event["WindowOpenedOrChanged"]["window"])
            wid = win["id"]
            prev = self.windows.get(wid)
            self.windows[wid] = win
            # If the user explicitly tiled a manually pinned window (Mod+V),
            # release its manual pin so it stays tiled until pinned again.
            if (
                prev is not None
                and prev.get("is_floating")
                and not win.get("is_floating")
                and wid in self.pinned_ids
            ):
                self.pinned_ids.discard(wid)
            return []

        if "WindowClosed" in event:
            wid = event["WindowClosed"]["id"]
            self.windows.pop(wid, None)
            self.pinned_ids.discard(wid)
            self.unpinned_auto_ids.discard(wid)
            return []

        if "OverviewOpenedOrClosed" in event:
            was_open = self.overview_open
            self.overview_open = bool(event["OverviewOpenedOrClosed"].get("is_open"))
            if was_open and not self.overview_open:
                return self.pending_moves()
            return []

        return []

    def set_pinned(self, window: dict, mode: str) -> tuple[str, bool]:
        """Apply 'toggle', 'pin', or 'unpin' to a window.

        Returns (resulting_status, needs_float) where resulting_status is
        'pinned' or 'unpinned', and needs_float is True when the caller should
        move the window to Niri's floating layout first.
        """
        wid = window["id"]
        self.windows[wid] = dict(window)
        currently_sticky = self.is_sticky(window)

        if mode == "toggle":
            want_pin = not currently_sticky
        elif mode == "pin":
            want_pin = True
        elif mode == "unpin":
            want_pin = False
        else:
            raise ValueError(f"unknown mode: {mode}")

        if want_pin:
            needs_float = not bool(window.get("is_floating"))
            self.unpinned_auto_ids.discard(wid)
            self.pinned_ids.add(wid)
            self.windows[wid]["is_floating"] = True
            return "pinned", needs_float

        self.pinned_ids.discard(wid)
        if self.is_auto_sticky(window):
            self.unpinned_auto_ids.add(wid)
        return "unpinned", False

    def reset_stream_state(self) -> None:
        """Drop cached Niri snapshots before reconnecting while keeping pin sets."""
        self.workspaces.clear()
        self.active_ws_by_output.clear()
        self.windows.clear()
        self.overview_open = False


def control_socket_path() -> Path:
    runtime = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    return Path(runtime) / "niri-sticky.sock"


def niri_request(niri_socket: str, payload: object, timeout: float = 2.0) -> dict:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.settimeout(timeout)
        sock.connect(niri_socket)
        sock.sendall((json.dumps(payload) + "\n").encode("utf-8"))
        sock.shutdown(socket.SHUT_WR)
        reader = sock.makefile("r", encoding="utf-8")
        line = reader.readline()
    if not line:
        raise OSError("empty reply from niri IPC")
    return json.loads(line)


def move_window_to_workspace(niri_socket: str, window_id: int, workspace_id: int) -> None:
    niri_request(
        niri_socket,
        {
            "Action": {
                "MoveWindowToWorkspace": {
                    "window_id": window_id,
                    "reference": {"Id": workspace_id},
                    "focus": False,
                }
            }
        },
    )


def move_window_to_floating(niri_socket: str, window_id: int) -> None:
    niri_request(niri_socket, {"Action": {"MoveWindowToFloating": {"id": window_id}}})


def focused_window(niri_socket: str) -> dict | None:
    reply = niri_request(niri_socket, "FocusedWindow")
    ok = reply.get("Ok")
    if isinstance(ok, dict):
        return ok.get("FocusedWindow")
    return None


def show_osd(status: str, title: str) -> None:
    noctalia = shutil.which("noctalia")
    if not noctalia:
        return
    icon = "pinned" if status == "pinned" else "pinned-off"
    prefix = "已钉住" if status == "pinned" else "取消钉住"
    short = title if len(title) <= 28 else title[:27] + "…"
    try:
        subprocess.run(
            [noctalia, "msg", "osd-show", icon, f"{prefix} · {short}"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=1.5,
            check=False,
        )
    except OSError:
        pass


def handle_control_command(
    state: StickyState, niri_socket: str, cmd: str
) -> dict:
    if cmd == "list":
        items = []
        for wid in state.sticky_ids():
            win = state.windows[wid]
            items.append(
                {
                    "id": wid,
                    "app_id": win.get("app_id"),
                    "title": win.get("title"),
                    "workspace_id": win.get("workspace_id"),
                    "manual": wid in state.pinned_ids,
                }
            )
        return {"status": "ok", "windows": items}

    if cmd not in ("toggle", "pin", "unpin"):
        return {"status": "error", "error": f"unknown command: {cmd}"}

    win = focused_window(niri_socket)
    if not win:
        return {"status": "none"}

    status, needs_float = state.set_pinned(win, cmd)
    if needs_float:
        move_window_to_floating(niri_socket, win["id"])

    title = win.get("title") or win.get("app_id") or f"Window {win['id']}"
    return {"status": status, "id": win["id"], "title": title}


DEFAULT_RECONNECT_DELAYS: tuple[float, ...] = (0.2, 0.5, 1.0, 2.0)


def _open_event_stream(
    niri_socket: str, timeout: float = 2.0
) -> tuple[socket.socket, bytes]:
    event_sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        event_sock.settimeout(timeout)
        event_sock.connect(niri_socket)
        event_sock.sendall(b'"EventStream"\n')

        # Read initial Handled reply synchronously before switching to non-blocking.
        buf = b""
        while b"\n" not in buf:
            chunk = event_sock.recv(4096)
            if not chunk:
                raise OSError("niri closed event stream before Handled")
            buf += chunk
        first_line, buf = buf.split(b"\n", 1)
        reply = json.loads(first_line.decode("utf-8"))
        if "Ok" not in reply:
            raise OSError(f"niri rejected EventStream: {reply}")
        event_sock.setblocking(False)
        return event_sock, buf
    except BaseException:
        event_sock.close()
        raise


def run_daemon(
    niri_socket: str,
    ctl_path: Path,
    *,
    stop_event: threading.Event | None = None,
    reconnect_delays: tuple[float, ...] = DEFAULT_RECONNECT_DELAYS,
) -> int:
    state = StickyState()
    stop = False

    def _stop(_signum, _frame):
        nonlocal stop
        stop = True

    def should_stop() -> bool:
        return stop or (stop_event is not None and stop_event.is_set())

    try:
        signal.signal(signal.SIGTERM, _stop)
        signal.signal(signal.SIGINT, _stop)
    except ValueError:
        pass

    select_timeout = 0.05 if stop_event is not None else 1.0
    server: socket.socket | None = None
    event_sock: socket.socket | None = None
    sel: selectors.BaseSelector | None = None
    ctl_bound = False
    buf = b""

    def process_lines() -> None:
        nonlocal buf
        while b"\n" in buf:
            raw, buf = buf.split(b"\n", 1)
            if not raw.strip():
                continue
            try:
                event = json.loads(raw.decode("utf-8"))
                moves = state.apply_event(event)
            except (ValueError, KeyError) as err:
                print(f"niri-sticky: bad event: {err}", file=sys.stderr)
                continue
            for wid, ws_id in moves:
                try:
                    move_window_to_workspace(niri_socket, wid, ws_id)
                except (OSError, ValueError) as err:
                    print(
                        f"niri-sticky: move window {wid} -> ws {ws_id} failed: {err}",
                        file=sys.stderr,
                    )

    def handle_control() -> None:
        assert server is not None
        try:
            conn, _ = server.accept()
        except BlockingIOError:
            return
        with conn:
            conn.settimeout(2.0)
            try:
                req = conn.recv(4096).decode("utf-8").strip()
                cmd = json.loads(req).get("cmd", "") if req else ""
                resp = handle_control_command(state, niri_socket, cmd)
            except (OSError, ValueError) as err:
                resp = {"status": "error", "error": str(err)}
            try:
                conn.sendall((json.dumps(resp) + "\n").encode("utf-8"))
            except OSError:
                pass

    def reconnect_event_stream() -> bool:
        nonlocal event_sock, buf
        assert sel is not None
        if event_sock is not None:
            try:
                sel.unregister(event_sock)
            except KeyError:
                pass
            event_sock.close()
            event_sock = None
        buf = b""
        state.reset_stream_state()

        for delay in reconnect_delays:
            deadline = time.monotonic() + delay
            while not should_stop():
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    break
                try:
                    ready = sel.select(timeout=min(remaining, select_timeout))
                except InterruptedError:
                    continue
                for key, _ in ready:
                    if key.data == "control":
                        handle_control()
            if should_stop():
                return False
            try:
                event_sock, buf = _open_event_stream(niri_socket)
                sel.register(event_sock, selectors.EVENT_READ, "events")
                print("niri-sticky: reconnected to niri event stream", file=sys.stderr)
                process_lines()
                return True
            except (OSError, ValueError) as err:
                print(f"niri-sticky: reconnect failed: {err}", file=sys.stderr)

        print("niri-sticky: event stream unavailable, exiting", file=sys.stderr)
        return False

    try:
        ctl_path.parent.mkdir(parents=True, exist_ok=True)
        if ctl_path.exists():
            ctl_path.unlink()

        server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        server.bind(str(ctl_path))
        ctl_bound = True
        os.chmod(ctl_path, 0o600)
        server.listen(8)
        server.setblocking(False)

        try:
            event_sock, buf = _open_event_stream(niri_socket)
        except (OSError, ValueError) as err:
            print(f"niri-sticky: failed to connect event stream: {err}", file=sys.stderr)
            return 1

        sel = selectors.DefaultSelector()
        sel.register(event_sock, selectors.EVENT_READ, "events")
        sel.register(server, selectors.EVENT_READ, "control")

        process_lines()
        while not should_stop():
            try:
                ready = sel.select(timeout=select_timeout)
            except InterruptedError:
                continue
            for key, _ in ready:
                if key.data == "events":
                    assert event_sock is not None
                    disconnect_reason: str | None = None
                    try:
                        chunk = event_sock.recv(65536)
                    except BlockingIOError:
                        continue
                    except OSError as err:
                        disconnect_reason = str(err)
                        chunk = b""
                    if not chunk:
                        reason = disconnect_reason or "EOF"
                        print(
                            f"niri-sticky: event stream closed ({reason}), reconnecting...",
                            file=sys.stderr,
                        )
                        if not reconnect_event_stream():
                            return 0 if should_stop() else 1
                        break
                    buf += chunk
                    process_lines()
                elif key.data == "control":
                    handle_control()
    finally:
        if sel is not None:
            sel.close()
        if event_sock is not None:
            event_sock.close()
        if server is not None:
            server.close()
        if ctl_bound:
            try:
                ctl_path.unlink(missing_ok=True)
            except OSError:
                pass
    return 0


def send_control_command(ctl_path: Path, cmd: str, osd: bool = True) -> int:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.settimeout(2.0)
        sock.connect(str(ctl_path))
        sock.sendall((json.dumps({"cmd": cmd}) + "\n").encode("utf-8"))
        reader = sock.makefile("r", encoding="utf-8")
        line = reader.readline()
    if not line:
        print("niri-sticky: empty reply from daemon", file=sys.stderr)
        return 1
    resp = json.loads(line)
    status = resp.get("status")
    if cmd == "list":
        print(json.dumps(resp.get("windows", []), ensure_ascii=False, indent=2))
        return 0
    if status in ("pinned", "unpinned"):
        if osd:
            show_osd(status, resp.get("title", ""))
        return 0
    if status == "none":
        return 0
    print(f"niri-sticky: {resp.get('error', 'unknown error')}", file=sys.stderr)
    return 1


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    cmd = args[0] if args else "toggle"
    ctl_path = control_socket_path()

    if cmd == "daemon":
        niri_socket = os.environ.get("NIRI_SOCKET", "")
        if not niri_socket:
            print("niri-sticky: NIRI_SOCKET is not set", file=sys.stderr)
            return 0
        return run_daemon(niri_socket, ctl_path)

    if cmd in ("toggle", "pin", "unpin", "list"):
        osd = "--no-osd" not in args[1:]
        try:
            return send_control_command(ctl_path, cmd, osd=osd)
        except OSError as err:
            print(f"niri-sticky: daemon unavailable ({err})", file=sys.stderr)
            return 1

    print("Usage: niri-sticky [daemon|toggle|pin|unpin|list]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
