"""Strip empty Flatpak permission tokens that crash Flatpak 1.18."""

from pathlib import Path
import os
import sys


def sanitize_line(line):
    if not line or line.lstrip().startswith(("[", "#")):
        return line
    if "=" not in line:
        return line
    key, value = line.split("=", 1)
    if ";" not in value:
        return line
    parts = [part for part in value.split(";") if part != ""]
    if not parts:
        return None
    return f"{key}={';'.join(parts)}"


def sanitize_text(text):
    lines = []
    for line in text.splitlines():
        sanitized = sanitize_line(line)
        if sanitized is None:
            continue
        lines.append(sanitized)
    if not lines:
        return "\n" if text.endswith("\n") else ""
    return "\n".join(lines) + "\n"


def sanitize_file(path):
    if path.is_symlink() or not path.is_file():
        return False
    original = path.read_text(encoding="utf-8")
    updated = sanitize_text(original)
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


def sanitize_dir(directory):
    directory = Path(directory)
    if not directory.is_dir():
        return []
    rewritten = []
    for path in sorted(directory.iterdir()):
        if sanitize_file(path):
            rewritten.append(path)
    return rewritten


def default_overrides_dir():
    data_home = os.environ.get("XDG_DATA_HOME")
    if data_home:
        return Path(data_home) / "flatpak/overrides"
    return Path.home() / ".local/share/flatpak/overrides"


def main(argv=None):
    args = sys.argv[1:] if argv is None else argv
    directory = Path(args[0]) if args else default_overrides_dir()
    sanitize_dir(directory)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
