"""Publish Mihomo config only after validation; keep the last usable file on failure."""

from pathlib import Path
import os
import shutil
import stat
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
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.trace = self.root / "trace.log"
        self.before = self.root / "before.yaml"
        self.proxies = self.root / "proxies.yaml"
        self.after = self.root / "after.yaml"
        self.dest = self.root / "run" / "config.yaml"
        self.before.write_text("mixed-port: 7890\n")
        self.proxies.write_text("proxies: []\n")
        self.after.write_text("rules:\n- MATCH,DIRECT\n")
        self.env = os.environ | {
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "HOME": str(self.root),
            "TRACE": str(self.trace),
            "MIHOMO_FAIL": "0",
        }
        self._write_cmd(
            "mihomo",
            r'''
echo "mihomo $*" >> "$TRACE"
file=""
while [ $# -gt 0 ]; do
  case "$1" in
    -t) shift ;;
    -f) file="$2"; shift 2 ;;
    *) shift ;;
  esac
done
echo "validated:$file" >> "$TRACE"
if [ "${MIHOMO_FAIL:-0}" = 1 ]; then
  exit 1
fi
if grep -Fq INVALID "$file"; then
  exit 1
fi
''',
        )

    def _write_cmd(self, name, body):
        path = self.bin / name
        path.write_text(f"#!{shutil.which('bash')}\nset -euo pipefail\n" + body)
        path.chmod(path.stat().st_mode | stat.S_IEXEC)

    def generate(self, **env):
        return subprocess.run(
            ["bash", str(SCRIPT), str(self.before), str(self.proxies), str(self.after), str(self.dest)],
            cwd=self.root,
            env=self.env | env,
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
        trace = self.trace.read_text()
        self.assertIn("validated:", trace)
        self.assertNotEqual(self.dest.as_posix(), trace.split("validated:")[-1].strip())
        self.assertTrue(Path(trace.split("validated:")[-1].strip()).exists() is False)

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

    def test_validation_failure_on_first_start_does_not_publish(self):
        result = self.generate(MIHOMO_FAIL="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.dest.exists())
        self.assertIn("keeping the last usable file", result.stderr)
        self.assertFalse(list(self.dest.parent.glob("config.yaml.tmp.*")) if self.dest.parent.exists() else [])

    def test_validation_failure_keeps_previous_file(self):
        self.assertEqual(self.generate().returncode, 0)
        previous = self.dest.read_text()
        self.after.write_text("INVALID\n")
        result = self.generate()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.dest.read_text(), previous)
        self.assertIn("keeping the last usable file", result.stderr)

    def test_validator_runs_before_publish(self):
        result = self.generate()
        self.assertEqual(result.returncode, 0, result.stderr)
        validated = self.trace.read_text().split("validated:")[-1].strip()
        self.assertTrue(validated.endswith("config.yaml.tmp." + validated.rsplit(".", 1)[-1]) or ".tmp." in validated)
        self.assertNotEqual(validated, str(self.dest))
