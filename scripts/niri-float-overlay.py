"""Keep the Proton coworker overlay floating on niri.

X11/Proton windows often receive their app-id after niri has already applied
open-floating rules, so a fullscreen overlay lands in the tiling layout.
Watch the event stream and float each matching window once.

Click-through is Proton's per-pixel ShapeInput (`WINE_LAYERED_OVERLAY_INPUT_SHAPE=1`).
xwayland-satellite must scale that region down to the viewport destination
(see patches/xwayland-satellite-scale-input-region.patch); otherwise niri
hit-tests buffer pixels on a logical-sized surface and clicks miss the pet
and its menus.
"""

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


def matches(window):
    if window.get("app_id") in APP_IDS:
        return True
    title = window.get("title") or ""
    return title in TITLES


def float_window(window_id):
    # The window can disappear between the event and the action; a failed
    # float is not worth tearing down the watcher for.
    subprocess.run(
        ["niri", "msg", "action", "move-window-to-floating", "--id", str(window_id)],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
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


def run_once():
    with subprocess.Popen(
        ["niri", "msg", "--json", "event-stream"],
        stdout=subprocess.PIPE,
        text=True,
    ) as process:
        try:
            watch(process.stdout)
        finally:
            process.terminate()


def main():
    while True:
        socket = niri_socket()
        if socket is None:
            time.sleep(1)
            continue
        os.environ["NIRI_SOCKET"] = socket
        try:
            run_once()
        except OSError as error:
            print(f"niri-float-overlay: event stream failed: {error}", file=sys.stderr)
        time.sleep(1)


if __name__ == "__main__":
    sys.exit(main())
