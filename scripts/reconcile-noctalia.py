"""Reconcile Nix-owned fields from the seed while preserving GUI-owned state."""

import os
from pathlib import Path
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


def table(document, path):
    for key in path.split("."):
        document = document.setdefault(key, tomlkit.table())
    return document


def reconcile(seed, document):
    for path, keys in OWNED.items():
        source, target = table(seed, path), table(document, path)
        for key in keys:
            target[key] = source[key]
    bar = table(document, "bar.main")
    for key in ("capsule_fill", "capsule_radius", "capsule_opacity", "capsule_border"):
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


def update(seed_path, state_path):
    original = state_path.read_bytes()
    seed = tomlkit.parse(seed_path.read_text())
    updated = tomlkit.dumps(reconcile(seed, tomlkit.parse(original.decode()))).encode()
    if updated == original:
        return
    # Stage in the same directory: failures never leave a truncated TOML file.
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
