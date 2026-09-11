"""Refresh KDE Connect only when needed."""

from pathlib import Path
import os
import shutil
import stat
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/kdeconnect-refresh.sh"


class KdeconnectRefreshTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.bin = Path(self.temp.name) / "bin"
        self.bin.mkdir()
        self.trace = Path(self.temp.name) / "trace.log"
        self.available = Path(self.temp.name) / "available"
        self.available.write_text("")
        self.env = os.environ | {
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "TRACE": str(self.trace),
            "AVAILABLE": str(self.available),
        }
        cli = self.bin / "kdeconnect-cli"
        cli.write_text(
            f"#!{shutil.which('bash')}\n"
            "set -euo pipefail\n"
            'echo "kdeconnect-cli $*" >> "$TRACE"\n'
            'if [ "${1:-}" = "--list-available" ]; then\n'
            '  cat "$AVAILABLE"\n'
            "  exit 0\n"
            "fi\n"
            'if [ "${1:-}" = "--refresh" ]; then\n'
            "  exit 0\n"
            "fi\n"
            "exit 2\n"
        )
        cli.chmod(cli.stat().st_mode | stat.S_IEXEC)

    def run_script(self, *args, available=""):
        self.available.write_text(available)
        self.trace.write_text("")
        return subprocess.run(
            ["bash", str(SCRIPT), *args],
            env=self.env,
            capture_output=True,
            text=True,
        )

    def test_skips_refresh_when_a_device_is_reachable(self):
        result = self.run_script("if-unreachable", available="2d71508e21384dd896da8fdd95fc6121\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--list-available", self.trace.read_text())
        self.assertNotIn("--refresh", self.trace.read_text())

    def test_refreshes_when_nothing_is_reachable(self):
        result = self.run_script("if-unreachable")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--refresh", self.trace.read_text())

    def test_always_refreshes_even_if_reachable(self):
        result = self.run_script("always", available="device\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--refresh", self.trace.read_text())
        self.assertNotIn("--list-available", self.trace.read_text())
