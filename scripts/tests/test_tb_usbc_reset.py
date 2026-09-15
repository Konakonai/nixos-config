"""Thunderbolt USB-C recovery skips live devices and bounces idle TB xHCI ports."""

from pathlib import Path
import os
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/reset-tb-usbc.sh"


class TbUsbcResetTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.ss = self.root / "sys/devices/pci0000:00/0000:00:0d.0/usb2/2-0:1.0/usb2-port1"
        self.ss2 = self.root / "sys/devices/pci0000:00/0000:00:0d.0/usb2/2-0:1.0/usb2-port2"
        self.hs = self.root / "sys/devices/pci0000:00/0000:00:0d.0/usb1/1-0:1.0/usb1-port1"
        self.typec = self.root / "sys/class/typec/port0"
        self.ucsi = self.root / "sys/bus/platform/drivers/ucsi_acpi"
        self.pci = self.root / "sys/bus/pci/devices/0000:00:0d.0/power"
        for path in (self.ss, self.ss2, self.hs, self.typec, self.ucsi, self.pci):
            path.mkdir(parents=True)
        (self.root / "run").mkdir()
        for port in (self.ss, self.ss2, self.hs):
            self._write(port / "state", "not attached\n")
            self._write(port / "disable", "0\n")
        self._write(self.typec / "data_role", "[device]\n")
        self._write(self.typec / "port0.0/active", "yes\n")
        self._write(self.typec / "port0.1/active", "yes\n")
        self._write(self.ucsi / "unbind", "")
        self._write(self.ucsi / "bind", "")
        self._write(self.pci / "control", "auto\n")

    def _write(self, path: Path, text: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def run_script(self, *args):
        env = os.environ | {"SYSROOT": str(self.root)}
        return subprocess.run(
            ["bash", str(SCRIPT), *args],
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
        self.assertEqual((self.pci / "control").read_text(), "on\n")

    def test_bounces_idle_ports_and_reloads_ucsi(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.ss / "disable").read_text(), "0\n")
        self.assertEqual((self.hs / "disable").read_text(), "0\n")
        self.assertEqual((self.ucsi / "unbind").read_text(), "USBC000:00\n")
        self.assertEqual((self.ucsi / "bind").read_text(), "USBC000:00\n")
        self.assertEqual((self.typec / "port0.0/active").read_text(), "0\n")
        self.assertIn("reload UCSI", result.stderr)

    def test_wakes_pci_even_when_idle_without_partner(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.pci / "control").read_text(), "on\n")
        self.assertNotIn("device appeared while waiting", result.stderr)

    def test_prepare_does_not_reload_ucsi(self):
        result = self.run_script("prepare")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.pci / "control").read_text(), "on\n")
        self.assertEqual((self.typec / "port0.0/active").read_text(), "0\n")
        self.assertEqual((self.ucsi / "unbind").read_text(), "")
        self.assertEqual((self.ss / "disable").read_text(), "0\n")
        self.assertIn("prepare", result.stderr)
