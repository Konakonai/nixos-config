"""Keep Proton desktop-overlay windows usable on niri.

X11/Proton windows often receive their app-id after niri has already applied
open-floating rules, so a fullscreen overlay lands in the tiling layout.
Build the input shape from the rendered top-level ARGB window with XRender.
Wine's client-surface readback is not equivalent to this composited drawable;
a fixed rectangle loses both transparent click-through and movable popup input.
"""

import ctypes
import fcntl
import json
import os
import select
import subprocess
import sys
import time
from pathlib import Path
from ctypes import (
    POINTER,
    Structure,
    byref,
    c_char_p,
    c_int,
    c_uint,
    c_ulong,
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


class XShapeEvent(Structure):
    _fields_ = [
        ("type", c_int), ("serial", c_ulong), ("send_event", c_int),
        ("display", c_void_p), ("window", c_ulong), ("kind", c_int),
        ("x", c_int), ("y", c_int), ("width", c_uint), ("height", c_uint),
        ("time", c_ulong), ("shaped", c_int),
    ]


class ShapeSession:
    def __init__(self):
        self.x11 = self.xext = self.render = self.dpy = None
        self.target = self.mask = self.picture = 0
        self.size = None
        self.failed = False
        self.shape_event = 0
        self.own_shapes = set()
        # Xlib's default handler exits the process on a window-close race.
        self.error_handler = ctypes.CFUNCTYPE(c_int, c_void_p, c_void_p)(self._error)

    def _error(self, display, event):
        self.failed = True
        return 0

    def reset(self):
        if self.dpy:
            if self.picture:
                self.render.XRenderFreePicture(self.dpy, self.picture)
            if self.mask:
                self.x11.XFreePixmap(self.dpy, self.mask)
        self.target = self.mask = self.picture = 0
        self.size = None
        self.failed = False
        self.own_shapes.clear()

    def close(self):
        self.reset()
        if self.dpy:
            self.x11.XCloseDisplay(self.dpy)
        self.dpy = None

    def _ensure_display(self):
        if self.dpy:
            return True
        self.x11, self.xext = _load_x11()
        self.render = ctypes.CDLL(os.environ.get(
            "NIRI_FLOAT_OVERLAY_LIBXRENDER", "libXrender.so.1"))
        x, e, r = self.x11, self.xext, self.render
        def bind(lib, name, args, result=None):
            fn = getattr(lib, name)
            fn.argtypes, fn.restype = args, result
        bind(x, "XSetErrorHandler", [type(self.error_handler)], c_void_p)
        x.XSetErrorHandler(self.error_handler)
        bind(x, "XCreatePixmap", [c_void_p, c_ulong, c_uint, c_uint, c_uint], c_ulong)
        bind(x, "XFreePixmap", [c_void_p, c_ulong])
        bind(x, "XNextRequest", [c_void_p], c_ulong)
        bind(x, "XPending", [c_void_p], c_int)
        bind(x, "XNextEvent", [c_void_p, c_void_p], c_int)
        bind(x, "XConnectionNumber", [c_void_p], c_int)
        bind(x, "XInternAtom", [c_void_p, c_char_p, c_int], c_ulong)
        bind(x, "XChangeProperty", [c_void_p, c_ulong, c_ulong, c_ulong,
                                  c_int, c_int, c_void_p, c_int])
        bind(e, "XShapeQueryExtension", [c_void_p, POINTER(c_int), POINTER(c_int)], c_int)
        bind(e, "XShapeSelectInput", [c_void_p, c_ulong, c_ulong])
        bind(e, "XShapeCombineMask", [c_void_p, c_ulong, c_int, c_int, c_int, c_ulong, c_int])
        bind(r, "XRenderFindStandardFormat", [c_void_p, c_int], c_void_p)
        bind(r, "XRenderCreatePicture", [c_void_p, c_ulong, c_void_p, c_ulong, c_void_p], c_ulong)
        bind(r, "XRenderFreePicture", [c_void_p, c_ulong])
        bind(r, "XRenderComposite", [c_void_p, c_int, c_ulong, c_ulong, c_ulong,
                                   c_int, c_int, c_int, c_int, c_int, c_int, c_uint, c_uint])
        self.dpy = x.XOpenDisplay(os.environ.get("DISPLAY", ":0").encode())
        if not self.dpy:
            return False
        event, error = c_int(), c_int()
        if not e.XShapeQueryExtension(self.dpy, byref(event), byref(error)):
            self.close()
            raise OSError("X Shape extension unavailable")
        self.shape_event = event.value
        self.opaque_atom = x.XInternAtom(self.dpy, b"_NET_WM_OPAQUE_REGION", 0)
        return True

    def _find_target(self):
        stack = _children(self.x11, self.dpy, self.x11.XDefaultRootWindow(self.dpy))
        while stack:
            window = stack.pop()
            if _window_name(self.x11, self.dpy, window) in X_TITLES:
                return window
            stack.extend(_children(self.x11, self.dpy, window))
        return 0

    def _geometry(self, window):
        root, x, y = c_ulong(), c_int(), c_int()
        width, height, border, depth = c_uint(), c_uint(), c_uint(), c_uint()
        if not self.x11.XGetGeometry(
            self.dpy, window, byref(root), byref(x), byref(y),
            byref(width), byref(height), byref(border), byref(depth),
        ) or depth.value != 32:
            return None
        return width.value, height.value

    def apply(self):
        if not self._ensure_display():
            return False
        if self.failed:
            self.reset()
        if not self.target:
            self.target = self._find_target()
            if not self.target:
                return False
            self.xext.XShapeSelectInput(self.dpy, self.target, 1)
        size = self._geometry(self.target)
        if not size or self.failed:
            self.reset()
            return False
        if size != self.size:
            if self.picture:
                self.render.XRenderFreePicture(self.dpy, self.picture)
            if self.mask:
                self.x11.XFreePixmap(self.dpy, self.mask)
            self.size = size
            self.mask = self.x11.XCreatePixmap(self.dpy, self.target, *size, 1)
            # PictStandardA1: alpha >= 0.5 takes input; faint shadows pass through.
            fmt = self.render.XRenderFindStandardFormat(self.dpy, 4)
            self.picture = self.render.XRenderCreatePicture(self.dpy, self.mask, fmt, 0, None)
        # An empty CARDINAL region explicitly forbids opaque-region optimizations.
        # This is only applied to the identified ARGB overlay, never other apps.
        self.x11.XChangeProperty(self.dpy, self.target, self.opaque_atom,
                                6, 32, 0, None, 0)
        return self.refresh()

    def refresh(self):
        if not self.target or not self.picture or self.failed:
            return False
        # Recreate the source picture: Wine may replace the backing buffer.
        fmt = self.render.XRenderFindStandardFormat(self.dpy, 0)  # ARGB32
        source = self.render.XRenderCreatePicture(self.dpy, self.target, fmt, 0, None)
        self.render.XRenderComposite(self.dpy, 1, source, 0, self.picture,
                                     0, 0, 0, 0, 0, 0, *self.size)  # PictOpSrc
        self.render.XRenderFreePicture(self.dpy, source)
        return self.restamp()

    def restamp(self):
        if not self.dpy or not self.target or not self.mask or self.failed:
            return False
        self.own_shapes.add(self.x11.XNextRequest(self.dpy))
        self.xext.XShapeCombineMask(self.dpy, self.target, SHAPE_INPUT,
                                    0, 0, self.mask, SHAPE_SET)
        self.x11.XFlush(self.dpy)
        return True

    def wait(self, timeout):
        if not self.dpy:
            time.sleep(timeout)
            return
        # React to Wine clearing/resetting ShapeInput instead of racing a 20ms timer.
        if not self.x11.XPending(self.dpy):
            select.select([self.x11.XConnectionNumber(self.dpy)], [], [], timeout)
        repair = False
        while self.x11.XPending(self.dpy):
            event = (c_ulong * 24)()  # sizeof(XEvent)
            self.x11.XNextEvent(self.dpy, byref(event))
            shape = ctypes.cast(byref(event), POINTER(XShapeEvent)).contents
            if shape.type == self.shape_event and shape.serial in self.own_shapes:
                self.own_shapes.discard(shape.serial)
                continue
            if (shape.type == self.shape_event and shape.window == self.target
                    and shape.kind == SHAPE_INPUT
                    and (not shape.shaped or not shape.width or not shape.height)):
                repair = True
        # Own ShapeNotify serials are ignored, including all-transparent frames.
        if repair and self.target:
            return self.restamp()
        return False


def tick(last_float, session):
    overlay_open = False
    for window in niri("windows"):
        if matches(window):
            overlay_open = True
            if should_float(window, last_float):
                float_window(window["id"])
    if not overlay_open:
        session.reset()
        return False
    session.apply()
    return True


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
    session = ShapeSession()
    last_niri = 0
    last_frame = 0
    try:
        while True:
            now = time.monotonic()
            try:
                if now - last_niri >= 0.4:
                    tick(last_float, session)
                    last_niri = now
                elif session.target and now - last_frame >= 1 / 30:
                    session.refresh()
                    last_frame = now
            except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
                print(f"niri-float-overlay: tick failed: {error}", file=sys.stderr)
            session.wait(0.005 if session.target else 0.2)
    finally:
        session.close()


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
