"""Concatenate Mihomo fragments and publish atomically. No mihomo -t."""

from pathlib import Path
import os
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/generate-mihomo-config.sh"


class MihomoConfigTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.before = self.root / "before.yaml"
        self.proxies = self.root / "proxies.yaml"
        self.after = self.root / "after.yaml"
        self.dest = self.root / "run" / "config.yaml"
        self.before.write_text("mixed-port: 7890\n")
        self.proxies.write_text("proxies: []\n")
        self.after.write_text("rules:\n- MATCH,DIRECT\n")
        self.env = os.environ | {"HOME": str(self.root)}

    def generate(self):
        return subprocess.run(
            ["bash", str(SCRIPT), str(self.before), str(self.proxies), str(self.after), str(self.dest)],
            cwd=self.root,
            env=self.env,
            capture_output=True,
            text=True,
        )

    def test_successful_generation_concatenates_and_publishes(self):
        result = self.generate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.dest.read_text(),
            "mixed-port: 7890\nproxies: []\nrules:\n- MATCH,DIRECT\n",
        )
        self.assertEqual(self.dest.stat().st_mode & 0o777, 0o600)
        self.assertFalse(list(self.dest.parent.glob("config.yaml.tmp.*")))

    def test_repeat_start_is_idempotent(self):
        self.assertEqual(self.generate().returncode, 0)
        first = self.dest.read_text()
        self.assertEqual(self.generate().returncode, 0)
        self.assertEqual(self.dest.read_text(), first)

    def test_missing_proxies_does_not_publish(self):
        self.proxies.unlink()
        result = self.generate()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.dest.exists())

    def test_does_not_invoke_mihomo(self):
        result = self.generate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("mihomo", result.stdout)
        self.assertNotIn("mihomo", result.stderr)
        self.assertFalse((self.dest.parent / "last-validation").exists())
