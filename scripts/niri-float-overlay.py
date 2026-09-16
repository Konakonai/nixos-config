"""Keep Proton desktop-overlay windows usable on niri.

X11/Proton windows often receive their app-id after niri has already applied
open-floating rules, so a fullscreen overlay lands in the tiling layout.
Let Wine generate the per-pixel input shape from the actual game surface.
The helper only keeps the full-screen game window floating in niri; it must
not replace Wine's game input region with a compositor screenshot mask.
"""

import fcntl
import json
import os
import subprocess
import sys
import time
from pathlib import Path

APP_IDS = {
    "steam_app_4564320",
    "YourCoworker.exe",
}
TITLES = {
    "YourCoworker",
    "Your Coworker",
    "With Your Coworker",
}


def niri_socket():
    env = os.environ.get("NIRI_SOCKET")
    if env and Path(env).exists():
        return env
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    socks = sorted(
        runtime.glob("niri*.sock"),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    return str(socks[0]) if socks else None


def niri(*args):
    return json.loads(subprocess.check_output(
        ["niri", "msg", "--json", *args], text=True, timeout=5,
    ))


def matches(window):
    if window.get("app_id") in APP_IDS:
        return True
    title = window.get("title") or ""
    return title in TITLES



def float_window(window_id):
    subprocess.run(
        ["niri", "msg", "action", "move-window-to-floating", "--id", str(window_id)],
        check=True,
        stdout=subprocess.DEVNULL,
        timeout=5,
    )


def should_float(window, last, min_interval=0.4):
    if not matches(window) or window.get("is_floating"):
        return False
    now = time.monotonic()
    window_id = window["id"]
    previous = last.get(window_id)
    if previous is not None and now - previous < min_interval:
        return False
    last[window_id] = now
    return True


def watch(stream, last=None):
    last = {} if last is None else last
    try:
        for line in stream:
            event = json.loads(line)
            if "WindowsChanged" in event:
                windows = event["WindowsChanged"]["windows"]
            elif "WindowOpenedOrChanged" in event:
                windows = [event["WindowOpenedOrChanged"]["window"]]
            else:
                continue
            for window in windows:
                if should_float(window, last):
                    float_window(window["id"])
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"niri-float-overlay: stopped: {error}", file=sys.stderr)


def tick(last_float):
    overlay_open = False
    for window in niri("windows"):
        if matches(window):
            overlay_open = True
            if should_float(window, last_float):
                float_window(window["id"])
    return overlay_open


def singleton_lock():
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp"))
    lock_path = runtime / "niri-float-overlay.lock"
    lock_file = open(lock_path, "w")
    try:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        lock_file.close()
        return None
    lock_file.write(str(os.getpid()))
    lock_file.flush()
    return lock_file


def run_loop():
    last_float = {}
    while True:
        try:
            tick(last_float)
        except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
            print(f"niri-float-overlay: tick failed: {error}", file=sys.stderr)
        time.sleep(0.4)


def main():
    lock_file = singleton_lock()
    if lock_file is None:
        print("niri-float-overlay: already running", file=sys.stderr)
        return 0
    try:
        while True:
            socket = niri_socket()
            if socket is None:
                time.sleep(1)
                continue
            os.environ["NIRI_SOCKET"] = socket
            run_loop()
    finally:
        lock_file.close()


if __name__ == "__main__":
    sys.exit(main())
