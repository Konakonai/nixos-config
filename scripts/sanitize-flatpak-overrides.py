"""Strip empty Flatpak permission tokens that crash Flatpak 1.18."""

import argparse
from pathlib import Path
import os
import sys


def sanitize_line(line, section=None, drop_env=(), drop_unset=()):
    if not line or line.lstrip().startswith(("[", "#")):
        return line
    if "=" not in line:
        return line
    key, value = line.split("=", 1)
    drop_env = set(drop_env)
    drop_unset = set(drop_unset)

    if key == "unset-environment":
        parts = [
            part
            for part in value.split(";")
            if part and part not in drop_unset and part not in drop_env
        ]
        if not parts:
            return None
        return f"{key}={';'.join(parts)}"

    if section == "Environment" and key in drop_env:
        return None

    if ";" not in value:
        return line
    parts = [part for part in value.split(";") if part != ""]
    if not parts:
        return None
    return f"{key}={';'.join(parts)}"


def sanitize_text(text, drop_env=(), drop_unset=()):
    lines = []
    section = None
    for line in text.splitlines():
        stripped = line.lstrip()
        if stripped.startswith("[") and stripped.endswith("]"):
            section = stripped[1:-1]
            lines.append(line)
            continue
        sanitized = sanitize_line(
            line,
            section=section,
            drop_env=drop_env,
            drop_unset=drop_unset,
        )
        if sanitized is None:
            continue
        lines.append(sanitized)
    if not lines:
        return "\n" if text.endswith("\n") else ""
    return "\n".join(lines) + "\n"


def sanitize_file(path, drop_env=(), drop_unset=()):
    if path.is_symlink() or not path.is_file():
        return False
    original = path.read_text(encoding="utf-8")
    updated = sanitize_text(original, drop_env=drop_env, drop_unset=drop_unset)
    if updated == original:
        return False

    staging = path.with_name(f".{path.name}.staging")
    try:
        staging.write_text(updated, encoding="utf-8")
        staging.replace(path)
    except Exception:
        if staging.exists():
            staging.unlink()
        raise
    return True


def sanitize_dir(directory, drop_env=(), drop_unset=()):
    directory = Path(directory)
    if not directory.is_dir():
        return []
    rewritten = []
    for path in sorted(directory.iterdir()):
        if sanitize_file(path, drop_env=drop_env, drop_unset=drop_unset):
            rewritten.append(path)
    return rewritten


def default_overrides_dir():
    data_home = os.environ.get("XDG_DATA_HOME")
    if data_home:
        return Path(data_home) / "flatpak/overrides"
    return Path.home() / ".local/share/flatpak/overrides"


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", nargs="?", type=Path)
    parser.add_argument("--drop-env", action="append", default=[])
    parser.add_argument("--drop-unset", action="append", default=[])
    args = parser.parse_args(sys.argv[1:] if argv is None else argv)
    directory = args.directory or default_overrides_dir()
    sanitize_dir(directory, drop_env=args.drop_env, drop_unset=args.drop_unset)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
