"""Reconcile Nix-owned fields from the seed while preserving GUI-owned state."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

import tomlkit


OWNED = {
    "theme": ("mode", "source", "custom_palette"),
    "bar.main": ("background_opacity", "reserve_space", "capsule"),
    "dock": ("background_opacity", "reserve_space"),
    "notification": ("background_opacity",),
    "osd": ("background_opacity",),
    "shell.panel": ("transparency_mode",),
    "shell.shadow": ("alpha",),
    "backdrop": ("enabled", "blur_intensity", "tint_intensity"),
    "lockscreen": ("blur_intensity", "tint_intensity"),
    "plugins": ("auto_update",),
}

CAPSULE_KEYS = ("capsule_fill", "capsule_radius", "capsule_opacity", "capsule_border")
THEME_KEYS = OWNED["theme"]


def table(document, path):
    for key in path.split("."):
        document = document.setdefault(key, tomlkit.table())
    return document


def lookup(document, path):
    node = document
    for key in path.split("."):
        if key not in node:
            return None
        node = node[key]
    return node


def reconcile(seed, document):
    for path, keys in OWNED.items():
        source, target = table(seed, path), table(document, path)
        for key in keys:
            target[key] = source[key]
    bar = table(document, "bar.main")
    for key in CAPSULE_KEYS:
        bar.pop(key, None)
    for section in ("dock", "lockscreen"):
        document[section].pop("monitors", None)
    opacity = seed["notification"]["background_opacity"]
    for widget in document.get("lockscreen_widgets", {}).get("widget", {}).values():
        if "settings" in widget:
            widget["settings"]["background_opacity"] = opacity
            widget["settings"]["input_opacity"] = opacity
    for source in document["plugins"].get("source", []):
        source.pop("auto_update", None)
    enabled = document["plugins"].setdefault("enabled", tomlkit.array())
    for plugin in seed["plugins"]["enabled"]:
        if plugin not in enabled:
            enabled.append(plugin)
    settings = document.setdefault("plugin_settings", tomlkit.table())
    for plugin, defaults in seed["plugin_settings"].items():
        target = settings.setdefault(plugin, tomlkit.table())
        for key, value in defaults.items():
            target.setdefault(key, value)
    return document


def snapshot(document):
    view = {}
    for path, keys in OWNED.items():
        node = lookup(document, path) or {}
        view[path] = {key: node.get(key) for key in keys}
    bar = lookup(document, "bar.main") or {}
    view["capsule"] = [key for key in CAPSULE_KEYS if key in bar]
    for section in ("dock", "lockscreen"):
        node = lookup(document, section) or {}
        view[f"{section}.monitors"] = "monitors" in node
    plugins = lookup(document, "plugins") or {}
    view["plugin_auto_update"] = [
        "auto_update" in source for source in plugins.get("source", [])
    ]
    view["plugins.enabled"] = list(plugins.get("enabled", []))
    return json.dumps(view, sort_keys=True, default=str)


def needs_write(seed, document):
    expected = reconcile(seed, tomlkit.parse(tomlkit.dumps(document)))
    return snapshot(expected) != snapshot(document)


def apply_theme_cli(seed):
    noctalia = shutil.which("noctalia")
    if noctalia is None:
        return False
    theme = seed.get("theme") or {}
    commands = []
    if "mode" in theme:
        commands.append([noctalia, "msg", "theme-mode-set", str(theme["mode"])])
    source = theme.get("source")
    palette = theme.get("custom_palette")
    if source is not None or palette is not None:
        command = [noctalia, "msg", "color-scheme-set", str(source or "custom")]
        if palette is not None:
            command.append(str(palette))
        commands.append(command)
    if not commands:
        return False
    for command in commands:
        result = subprocess.run(command, capture_output=True)
        if result.returncode != 0:
            return False
    return True


def update(seed_path, state_path):
    original = state_path.read_bytes()
    seed = tomlkit.parse(seed_path.read_text())
    document = tomlkit.parse(original.decode())
    if not needs_write(seed, document):
        print("noctalia: skip", file=sys.stderr)
        return

    if apply_theme_cli(seed):
        print("noctalia: cli", file=sys.stderr)
        original = state_path.read_bytes()
        document = tomlkit.parse(original.decode())
        if not needs_write(seed, document):
            return

    print("noctalia: file", file=sys.stderr)
    updated = tomlkit.dumps(reconcile(seed, tomlkit.parse(original.decode()))).encode()
    if updated == original:
        return
    fd, name = tempfile.mkstemp(prefix=".settings-", dir=state_path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(fd, "wb") as output:
            output.write(updated)
            output.flush()
            os.fsync(output.fileno())
        if state_path.read_bytes() != original:
            raise RuntimeError("Noctalia settings changed during reconciliation; retry rebuild")
        temporary.replace(state_path)
    finally:
        temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    update(*map(Path, sys.argv[1:]))
