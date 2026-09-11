"""Accept Zed JSONC without reporting comments as drift corruption."""

from pathlib import Path
import json
import os
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/jsonc.py"


class JsoncTest(unittest.TestCase):
    def canonicalize(self, text):
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
            handle.write(text)
            path = handle.name
        try:
            result = subprocess.run(
                ["python3", str(SCRIPT), "canonicalize", path],
                check=True,
                capture_output=True,
                text=True,
            )
            return result.stdout
        finally:
            os.unlink(path)

    def test_strict_json_round_trips(self):
        self.assertEqual(
            json.loads(self.canonicalize('{"b": 1, "a": 2}')),
            {"a": 2, "b": 1},
        )

    def test_line_and_block_comments_are_ignored(self):
        text = """
        {
          // keep this workspace trusted
          "session": { "trust_all_worktrees": true },
          /* palette */
          "theme": "Noctalia Light"
        }
        """
        self.assertEqual(
            json.loads(self.canonicalize(text)),
            {"session": {"trust_all_worktrees": True}, "theme": "Noctalia Light"},
        )

    def test_comment_markers_inside_strings_are_preserved(self):
        self.assertEqual(
            json.loads(self.canonicalize('{"url": "https://example.com/path"}')),
            {"url": "https://example.com/path"},
        )
