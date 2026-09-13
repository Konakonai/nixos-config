"""Steam launch option: steam-follow %command% (Niri only)."""

import json
import os
import signal
import subprocess
import sys
import threading


def niri(*args):
    return json.loads(subprocess.check_output(
        ["niri", "msg", "--json", *args], text=True, timeout=5,
    ))


def launcher_output(windows, workspaces):
    outputs = {ws["id"]: ws["output"] for ws in workspaces}
    launchers = [w for w in windows if w.get("app_id") == "steam"
                 and outputs.get(w.get("workspace_id"))]
    if not launchers:
        return None
    def focus_time(window):
        stamp = window.get("focus_timestamp") or {}
        return stamp.get("secs", 0), stamp.get("nanos", 0)
    launcher = max(launchers, key=focus_time)
    return outputs[launcher["workspace_id"]]


def watch(stream, existing, app_id, output):
    handled = set(existing)
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
                if window["id"] in handled or window.get("app_id") != app_id:
                    continue
                # A late app-id update must still be recognized. Handle each new
                # game window only once, so manual moves are never undone.
                handled.add(window["id"])
                workspaces = niri("workspaces")
                outputs = {ws["id"]: ws["output"] for ws in workspaces}
                if output not in outputs.values():
                    continue  # Monitor disconnected during launch.
                if outputs.get(window.get("workspace_id")) == output:
                    continue
                subprocess.run([
                    "niri", "msg", "action", "move-window-to-monitor",
                    "--id", str(window["id"]), output,
                ], check=True, stdout=subprocess.DEVNULL, timeout=5)
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"steam-follow: placement stopped: {error}", file=sys.stderr)


def main():
    command = sys.argv[1:]
    if not command:
        sys.exit("Usage: steam-follow %command% (Steam launch options)")
    app_id = os.environ.get("SteamAppId", "")
    if not os.environ.get("NIRI_SOCKET") or not app_id.isdecimal():
        os.execvp(command[0], command)
    try:
        windows = niri("windows")
        output = launcher_output(windows, niri("workspaces"))
        if output is None:
            os.execvp(command[0], command)
        events = subprocess.Popen(
            ["niri", "msg", "--json", "event-stream"],
            stdout=subprocess.PIPE, text=True,
        )
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"steam-follow: launching without placement: {error}", file=sys.stderr)
        os.execvp(command[0], command)

    watcher = threading.Thread(
        target=watch,
        args=(events.stdout, {w["id"] for w in windows}, f"steam_app_{app_id}", output),
        daemon=True,
    )
    watcher.start()
    try:
        game = subprocess.Popen(command)
        for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
            signal.signal(sig, lambda signum, frame: game.send_signal(signum))
        status = game.wait()
    finally:
        events.terminate()
        events.wait(timeout=5)
        watcher.join(timeout=5)
        events.stdout.close()
    return status if status >= 0 else 128 - status


if __name__ == "__main__":
    sys.exit(main())
