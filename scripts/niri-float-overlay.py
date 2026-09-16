"""Float Proton desktop-overlay windows that niri tiled on first map.

X11/Proton windows often receive their app-id after niri has already applied
open-floating rules, so a fullscreen overlay lands in the tiling layout.
Watch the event stream and float each matching window once.
"""

import json
import os
import subprocess
import sys

APP_IDS = {
    "steam_app_4564320",
    "YourCoworker.exe",
}
TITLES = {
    "YourCoworker",
    "Your Coworker",
    "With Your Coworker",
}


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


def watch(stream, handled):
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
                window_id = window["id"]
                if window_id in handled or not matches(window):
                    continue
                handled.add(window_id)
                if window.get("is_floating"):
                    continue
                float_window(window_id)
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"niri-float-overlay: stopped: {error}", file=sys.stderr)


def existing_matches():
    handled = set()
    try:
        for window in niri("windows"):
            if not matches(window):
                continue
            handled.add(window["id"])
            if not window.get("is_floating"):
                float_window(window["id"])
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"niri-float-overlay: initial scan failed: {error}", file=sys.stderr)
    return handled


def main():
    if not os.environ.get("NIRI_SOCKET"):
        return 0
    handled = existing_matches()
    try:
        events = subprocess.Popen(
            ["niri", "msg", "--json", "event-stream"],
            stdout=subprocess.PIPE,
            text=True,
        )
    except OSError as error:
        print(f"niri-float-overlay: no event stream: {error}", file=sys.stderr)
        return 0
    try:
        watch(events.stdout, handled)
    finally:
        events.terminate()
        events.wait(timeout=5)
        if events.stdout is not None:
            events.stdout.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
