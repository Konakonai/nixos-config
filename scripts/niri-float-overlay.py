"""Keep the Proton coworker overlay floating, and keep the pet clickable.

Two jobs, both niri-specific:

1. X11/Proton windows often receive their app-id after niri has already applied
   open-floating rules, so a fullscreen overlay lands in the tiling layout.
   Watch the event stream and float each matching window once.

2. Stamp X11 ShapeInput rectangles over the pet. Xwayland turns that shape into
   `wl_surface.set_input_region`, and xwayland-satellite forwards the region to
   niri *without* dividing by the viewport scale, while pointer events *are*
   multiplied by that scale. A single buffer-space rectangle therefore misses
   the visible pet (niri hit-tests it in logical pixels). The helper stamps
   both the buffer-space box (so Wine sees the scaled click) and the
   logical-space box (so niri sends the click). Transparent areas outside both
   boxes pass through. Proton stays on INPUT_SHAPE=0 -- see README.
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


def clickable_rects(buffer_width, buffer_height, logical_width=None, logical_height=None):
    """ShapeInput rectangles in X (buffer) coordinates.

    niri's surface is the viewport destination (logical pixels). Satellite
    copies Xwayland's input region onto that surface unchanged, so a rect
    computed from the X window size is tested in the wrong space. A second
    rect computed from niri's logical window size lands on the visible pet.
    """
    rects = [clickable_rect(buffer_width, buffer_height)]
    if (
        logical_width
        and logical_height
        and (logical_width, logical_height) != (buffer_width, buffer_height)
    ):
        logical = clickable_rect(logical_width, logical_height)
        if logical != rects[0]:
            rects.append(logical)
    return rects


def logical_size_of(window):
    size = (window.get("layout") or {}).get("window_size")
    if isinstance(size, (list, tuple)) and len(size) >= 2:
        width, height = int(size[0]), int(size[1])
        if width > 0 and height > 0:
            return (width, height)
    return None


class OverlayState:
    """Logical (niri) size of the overlay, shared with the shape thread."""

    def __init__(self):
        self._lock = threading.Lock()
        self._logical_size = None

    def set_logical_size(self, size):
        with self._lock:
            self._logical_size = size

    def logical_size(self):
        with self._lock:
            return self._logical_size


_OUTPUT_SCALE = []


def output_scale():
    if _OUTPUT_SCALE:
        return _OUTPUT_SCALE[0]
    try:
        raw = subprocess.run(
            ["niri", "msg", "--json", "outputs"],
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        ).stdout
        data = json.loads(raw)
    except (OSError, ValueError, subprocess.SubprocessError):
        return None
    if not isinstance(data, dict):
        return None
    for value in data.values():
        scale = ((value or {}).get("logical") or {}).get("scale")
        if scale:
            _OUTPUT_SCALE.append(float(scale))
            return _OUTPUT_SCALE[0]
    return None


def inferred_logical_size(buffer_width, buffer_height):
    scale = output_scale()
    if not scale or scale == 1.0:
        return None
    return (max(1, round(buffer_width / scale)), max(1, round(buffer_height / scale)))


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


def watch(stream, last=None, overlay_state=None):
    last = {} if last is None else last
    try:
        for line in stream:
            event = json.loads(line)
            if "WindowsChanged" in event:
                windows = event["WindowsChanged"]["windows"]
                if overlay_state is not None and not any(matches(window) for window in windows):
                    overlay_state.set_logical_size(None)
            elif "WindowOpenedOrChanged" in event:
                windows = [event["WindowOpenedOrChanged"]["window"]]
            else:
                continue
            for window in windows:
                if overlay_state is not None and matches(window):
                    size = logical_size_of(window)
                    if size:
                        overlay_state.set_logical_size(size)
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
    """Keeps the pet rectangles stamped on the overlay's X11 input shape."""

    def __init__(self, overlay_state=None):
        self.overlay_state = overlay_state
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
        logical = self.overlay_state.logical_size() if self.overlay_state else None
        if not logical:
            logical = inferred_logical_size(width.value, height.value)
        logical_w, logical_h = logical if logical else (None, None)
        return clickable_rects(width.value, height.value, logical_w, logical_h)

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
        n = len(self.rect)
        shapes = (XRectangle * n)(*[XRectangle(x, y, w, h) for x, y, w, h in self.rect])
        # Flush rather than XSync: a round-trip on every tick stalls drags.
        self.xext.XShapeCombineRectangles(
            self.dpy, self.target, SHAPE_INPUT, 0, 0, shapes, n, SHAPE_SET, UNSORTED,
        )
        self.x11.XFlush(self.dpy)
        return not self.failed


def shape_loop(stop, overlay_state=None):
    """Restamp the pet rectangles until `stop` is set. Runs off the event stream."""
    session = ShapeSession(overlay_state)
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


def run_once(overlay_state=None):
    with subprocess.Popen(
        ["niri", "msg", "--json", "event-stream"],
        stdout=subprocess.PIPE,
        text=True,
    ) as process:
        try:
            watch(process.stdout, overlay_state=overlay_state)
        finally:
            process.terminate()


def main():
    # The systemd user unit is the only launcher, so it owns single-instance.
    stop = threading.Event()
    overlay_state = OverlayState()
    shaper = threading.Thread(target=shape_loop, args=(stop, overlay_state), daemon=True)
    shaper.start()
    try:
        while True:
            socket = niri_socket()
            if socket is None:
                time.sleep(1)
                continue
            os.environ["NIRI_SOCKET"] = socket
            try:
                run_once(overlay_state)
            except OSError as error:
                print(f"niri-float-overlay: event stream failed: {error}", file=sys.stderr)
            time.sleep(1)
    finally:
        stop.set()


if __name__ == "__main__":
    sys.exit(main())
