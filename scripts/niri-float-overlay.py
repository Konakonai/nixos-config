"""Keep the Proton coworker overlay floating, and keep the pet clickable.

Two jobs, both niri-specific:

1. X11/Proton windows often receive their app-id after niri has already applied
   open-floating rules, so a fullscreen overlay lands in the tiling layout.
   Watch the event stream and float each matching window once.

2. Stamp a small X11 ShapeInput rectangle over the pet. This does NOT give
   click-through: xwayland-satellite (which niri embeds) never translates
   ShapeInput into `wl_surface.set_input_region`, so the overlay's full
   rectangle swallows every click on the desktop no matter what is stamped
   here -- measured with a virtual pointer against a probe window whose input
   shape was empty. What the region *does* control is which X client Xwayland
   hands an event to, i.e. whether the pet itself reacts. GE-Proton's per-pixel
   alpha region (`WINE_LAYERED_OVERLAY_INPUT_SHAPE=1`) is too tight to survive
   the compositor's coordinate drift on a fractional-scale output, so the pet
   stops responding; a rectangle around the pet is forgiving enough to work.
   Proton must therefore be left on INPUT_SHAPE=0 -- see README.
"""

import ctypes
import json
import os
import subprocess
import sys
import threading
import time
from pathlib import Path
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

# Fractions of the overlay window that the pet, its HUD, and its popups occupy.
# Measured from Proton's own per-pixel alpha region on a 3840x2160 overlay: the
# union of two samples was x 2440..3212, y 732..1500, i.e. x 0.635..0.836 and
# y 0.339..0.694. Padded out to absorb the walk animation and the wardrobe/pose
# popups that open beside the character.
PET_X, PET_Y = 0.60, 0.31
PET_W, PET_H = 0.28, 0.42

RESTAMP_INTERVAL = 0.02


class XRectangle(Structure):
    _fields_ = [
        ("x", c_short),
        ("y", c_short),
        ("width", c_ushort),
        ("height", c_ushort),
    ]


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


def clickable_rect(width, height):
    return (
        int(width * PET_X),
        int(height * PET_Y),
        max(1, int(width * PET_W)),
        max(1, int(height * PET_H)),
    )


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
    x11.XFlush.argtypes = [c_void_p]
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


class ShapeSession:
    """Keeps the pet rectangle stamped on the overlay's X11 input shape."""

    def __init__(self):
        self.x11 = None
        self.xext = None
        self.dpy = None
        self.target = 0
        self.rect = None
        self.failed = False
        self.error_handler = ctypes.CFUNCTYPE(c_int, c_void_p, c_void_p)(self._on_x_error)

    def _on_x_error(self, _display, _event):
        self.failed = True
        return 0

    def close(self):
        if self.dpy is not None and self.x11 is not None:
            self.x11.XCloseDisplay(self.dpy)
        self.dpy = None
        self.target = 0
        self.rect = None
        self.failed = False

    def _ensure_display(self):
        if self.dpy is not None:
            return True
        try:
            self.x11, self.xext = _load_x11()
            self.x11.XSetErrorHandler.argtypes = [type(self.error_handler)]
            self.x11.XSetErrorHandler.restype = c_void_p
            self.x11.XSetErrorHandler(self.error_handler)
        except OSError as error:
            print(f"niri-float-overlay: X11 libraries unavailable: {error}", file=sys.stderr)
            return False
        self.dpy = self.x11.XOpenDisplay(os.environ.get("DISPLAY", ":0").encode())
        return bool(self.dpy)

    def _find_target(self):
        stack = _children(self.x11, self.dpy, self.x11.XDefaultRootWindow(self.dpy))
        seen = set()
        while stack:
            window = stack.pop()
            if window in seen:
                continue
            seen.add(window)
            if _window_name(self.x11, self.dpy, window) in X_TITLES:
                return window
            stack.extend(_children(self.x11, self.dpy, window))
        return 0

    def _geometry(self, window):
        root = c_ulong()
        x = c_int()
        y = c_int()
        width = c_uint()
        height = c_uint()
        border = c_uint()
        depth = c_uint()
        if not self.x11.XGetGeometry(
            self.dpy, window, byref(root), byref(x), byref(y),
            byref(width), byref(height), byref(border), byref(depth),
        ):
            return None
        return clickable_rect(width.value, height.value)

    def apply(self):
        if not self._ensure_display():
            return False
        if self.failed:
            self.target = 0
            self.rect = None
            self.failed = False
        if not self.target:
            self.target = self._find_target()
            self.rect = None
        if not self.target:
            return False
        rect = self._geometry(self.target)
        if rect is None or self.failed:
            self.target = 0
            self.rect = None
            self.failed = False
            return False
        self.rect = rect
        return self.restamp()

    def restamp(self):
        if self.dpy is None or not self.target or self.rect is None:
            return False
        rx, ry, rw, rh = self.rect
        shape = XRectangle(rx, ry, rw, rh)
        # Flush rather than XSync: an round-trip on every tick stalls drags.
        self.xext.XShapeCombineRectangles(
            self.dpy, self.target, SHAPE_INPUT, 0, 0, byref(shape), 1, SHAPE_SET, UNSORTED,
        )
        self.x11.XFlush(self.dpy)
        return not self.failed


def shape_loop(stop):
    """Restamp the pet rectangle until `stop` is set. Runs off the event stream."""
    session = ShapeSession()
    last_locate = 0.0
    try:
        while not stop.is_set():
            try:
                now = time.monotonic()
                if not session.target or now - last_locate >= 1.0:
                    session.apply()
                    last_locate = now
                else:
                    session.restamp()
            except (OSError, ValueError) as error:
                print(f"niri-float-overlay: shape tick failed: {error}", file=sys.stderr)
                session.close()
            stop.wait(RESTAMP_INTERVAL)
    finally:
        session.close()


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
    # The systemd user unit is the only launcher, so it owns single-instance.
    stop = threading.Event()
    shaper = threading.Thread(target=shape_loop, args=(stop,), daemon=True)
    shaper.start()
    try:
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
    finally:
        stop.set()


if __name__ == "__main__":
    sys.exit(main())
