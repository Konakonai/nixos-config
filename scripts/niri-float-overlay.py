"""Keep Proton desktop-overlay windows usable on niri.

X11/Proton windows often receive their app-id after niri has already applied
open-floating rules, so a fullscreen overlay lands in the tiling layout.
Wine's ALPHA overlay also cannot read a useful alpha mask from Xwayland, so
it either eats all clicks or punches the whole window out. This helper floats
matching windows and sets a center input region covering the character and HUD.
"""

import ctypes
import json
import os
import subprocess
import sys
import time
from ctypes import (
    POINTER,
    Structure,
    byref,
    c_char_p,
    c_int,
    c_short,
    c_uint,
    c_ulong,
    c_ushort,
    c_void_p,
)

APP_IDS = {
    "steam_app_4564320",
    "YourCoworker.exe",
}
TITLES = {
    "YourCoworker",
    "Your Coworker",
    "With Your Coworker",
}
X_TITLES = {"YourCoworker"}
SHAPE_INPUT = 2
SHAPE_SET = 0
UNSORTED = 0


class XRectangle(Structure):
    _fields_ = [
        ("x", c_short),
        ("y", c_short),
        ("width", c_ushort),
        ("height", c_ushort),
    ]


def niri(*args):
    return json.loads(subprocess.check_output(
        ["niri", "msg", "--json", *args], text=True, timeout=5,
    ))


def matches(window):
    if window.get("app_id") in APP_IDS:
        return True
    title = window.get("title") or ""
    return title in TITLES


def clickable_rect(width, height):
    return (
        int(width * 0.28),
        int(height * 0.18),
        max(1, int(width * 0.44)),
        max(1, int(height * 0.68)),
    )


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


def _load_x11():
    x11_path = os.environ.get("NIRI_FLOAT_OVERLAY_LIBX11", "libX11.so.6")
    xext_path = os.environ.get("NIRI_FLOAT_OVERLAY_LIBXEXT", "libXext.so.6")
    x11 = ctypes.CDLL(x11_path, use_errno=True)
    xext = ctypes.CDLL(xext_path, use_errno=True)
    x11.XOpenDisplay.restype = c_void_p
    x11.XOpenDisplay.argtypes = [c_char_p]
    x11.XDefaultRootWindow.restype = c_ulong
    x11.XDefaultRootWindow.argtypes = [c_void_p]
    x11.XQueryTree.restype = c_int
    x11.XQueryTree.argtypes = [
        c_void_p, c_ulong, POINTER(c_ulong), POINTER(c_ulong),
        POINTER(POINTER(c_ulong)), POINTER(c_uint),
    ]
    x11.XFetchName.restype = c_int
    x11.XFetchName.argtypes = [c_void_p, c_ulong, POINTER(c_char_p)]
    x11.XGetGeometry.restype = c_int
    x11.XGetGeometry.argtypes = [
        c_void_p, c_ulong, POINTER(c_ulong), POINTER(c_int), POINTER(c_int),
        POINTER(c_uint), POINTER(c_uint), POINTER(c_uint), POINTER(c_uint),
    ]
    x11.XFree.argtypes = [c_void_p]
    x11.XCloseDisplay.argtypes = [c_void_p]
    x11.XSync.argtypes = [c_void_p, c_int]
    xext.XShapeCombineRectangles.argtypes = [
        c_void_p, c_ulong, c_int, c_int, c_int,
        POINTER(XRectangle), c_int, c_int, c_int,
    ]
    return x11, xext


def _window_name(x11, dpy, window):
    name = c_char_p()
    if not x11.XFetchName(dpy, window, byref(name)):
        return ""
    value = name.value.decode("utf-8", "replace") if name.value else ""
    if name:
        x11.XFree(name)
    return value


def _children(x11, dpy, window):
    root = c_ulong()
    parent = c_ulong()
    children = POINTER(c_ulong)()
    count = c_uint()
    if not x11.XQueryTree(dpy, window, byref(root), byref(parent), byref(children), byref(count)):
        return []
    found = [children[i] for i in range(count.value)]
    if count.value:
        x11.XFree(children)
    return found


def apply_input_shape():
    display = os.environ.get("DISPLAY", ":0").encode()
    try:
        x11, xext = _load_x11()
    except OSError as error:
        print(f"niri-float-overlay: X11 libraries unavailable: {error}", file=sys.stderr)
        return False
    dpy = x11.XOpenDisplay(display)
    if not dpy:
        return False
    try:
        stack = _children(x11, dpy, x11.XDefaultRootWindow(dpy))
        seen = set()
        target = 0
        while stack:
            window = stack.pop()
            if window in seen:
                continue
            seen.add(window)
            if _window_name(x11, dpy, window) in X_TITLES:
                target = window
                break
            stack.extend(_children(x11, dpy, window))
        if not target:
            return False
        root = c_ulong()
        x = c_int()
        y = c_int()
        width = c_uint()
        height = c_uint()
        border = c_uint()
        depth = c_uint()
        if not x11.XGetGeometry(
            dpy, target, byref(root), byref(x), byref(y),
            byref(width), byref(height), byref(border), byref(depth),
        ):
            return False
        rx, ry, rw, rh = clickable_rect(width.value, height.value)
        rect = XRectangle(rx, ry, rw, rh)
        xext.XShapeCombineRectangles(
            dpy, target, SHAPE_INPUT, 0, 0, byref(rect), 1, SHAPE_SET, UNSORTED,
        )
        x11.XSync(dpy, 0)
        return True
    finally:
        x11.XCloseDisplay(dpy)


def tick(last_float):
    for window in niri("windows"):
        if should_float(window, last_float):
            float_window(window["id"])
    apply_input_shape()


def main():
    if not os.environ.get("NIRI_SOCKET"):
        return 0
    last_float = {}
    while True:
        try:
            tick(last_float)
        except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
            print(f"niri-float-overlay: tick failed: {error}", file=sys.stderr)
        time.sleep(0.4)


if __name__ == "__main__":
    sys.exit(main())
