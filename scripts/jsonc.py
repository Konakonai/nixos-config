"""Canonicalize JSON or JSONC without treating comments as a parse failure."""

from pathlib import Path
import json
import sys


def strip_jsonc(text):
    out = []
    i = 0
    n = len(text)
    in_str = False
    escape = False
    while i < n:
        char = text[i]
        if in_str:
            out.append(char)
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == '"':
                in_str = False
            i += 1
            continue
        if char == '"':
            in_str = True
            out.append(char)
            i += 1
            continue
        if char == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if char == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i += 2
            continue
        out.append(char)
        i += 1
    return "".join(out)


def canonicalize(path):
    text = Path(path).read_text()
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        data = json.loads(strip_jsonc(text))
    return json.dumps(data, sort_keys=True, indent=2, ensure_ascii=False) + "\n"


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] != "canonicalize":
        print("usage: jsonc.py canonicalize <file>", file=sys.stderr)
        sys.exit(2)
    sys.stdout.write(canonicalize(sys.argv[2]))
