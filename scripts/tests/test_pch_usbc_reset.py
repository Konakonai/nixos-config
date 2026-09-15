"""PCH USB-C recovery skips live devices and only bounces idle SS01/HS02."""

from pathlib import Path
import os
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/reset-pch-usbc.sh"


class PchUsbcResetTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.ss = self.root / "sys/devices/pci0000:00/0000:00:14.0/usb4/4-0:1.0/usb4-port1"
        self.hs = self.root / "sys/devices/pci0000:00/0000:00:14.0/usb3/3-0:1.0/usb3-port2"
        self.typec = self.root / "sys/class/typec/port1"
        self.ucsi = self.root / "sys/bus/platform/drivers/ucsi_acpi"
        for path in (self.ss, self.hs, self.typec, self.ucsi):
            path.mkdir(parents=True)
        (self.root / "run").mkdir()
        self._write(self.ss / "state", "not attached\n")
        self._write(self.hs / "state", "not attached\n")
        self._write(self.ss / "disable", "0\n")
        self._write(self.hs / "disable", "0\n")
        self._write(self.typec / "data_role", "[device]\n")
        self._write(self.ucsi / "unbind", "")
        self._write(self.ucsi / "bind", "")

    def _write(self, path: Path, text: str) -> None:
        path.write_text(text)

    def run_script(self):
        env = os.environ | {"SYSROOT": str(self.root)}
        return subprocess.run(
            ["bash", str(SCRIPT)],
            env=env,
            capture_output=True,
            text=True,
        )

    def test_skips_when_superspeed_already_configured(self):
        self._write(self.ss / "state", "configured\n")
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.ss / "disable").read_text(), "0\n")
        self.assertEqual((self.ucsi / "unbind").read_text(), "")
        self.assertIn("already has a device", result.stderr)

    def test_bounces_idle_ports_and_reloads_ucsi(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.ss / "disable").read_text(), "0\n")
        self.assertEqual((self.hs / "disable").read_text(), "0\n")
        self.assertEqual((self.ucsi / "unbind").read_text(), "USBC000:00\n")
        self.assertEqual((self.ucsi / "bind").read_text(), "USBC000:00\n")
        self.assertIn("reload UCSI", result.stderr)

    def test_does_not_wait_without_partner(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("device appeared while waiting", result.stderr)
