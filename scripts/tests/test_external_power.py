"""external-power.sh is true for any non-battery supply, not just ADP0."""

from pathlib import Path
import os
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/external-power.sh"


class ExternalPowerTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "sys/class/power_supply").mkdir(parents=True)

    def add_supply(self, name, kind, online=None):
        path = self.root / "sys/class/power_supply" / name
        path.mkdir()
        (path / "type").write_text(f"{kind}\n")
        if online is not None:
            (path / "online").write_text(f"{online}\n")
        return path

    def run_script(self):
        env = os.environ | {"SYSROOT": str(self.root)}
        return subprocess.run(
            ["bash", str(SCRIPT)],
            env=env,
            capture_output=True,
            text=True,
        )

    def test_false_when_no_supplies_exist(self):
        self.assertEqual(self.run_script().returncode, 1)

    def test_ignores_battery_even_when_online(self):
        self.add_supply("BAT0", "Battery", "1")
        self.assertEqual(self.run_script().returncode, 1)

    def test_true_when_barrel_jack_is_online(self):
        self.add_supply("ADP0", "Mains", "1")
        self.add_supply("BAT0", "Battery")
        self.assertEqual(self.run_script().returncode, 0)

    def test_true_when_only_usb_pd_is_online(self):
        self.add_supply("ADP0", "Mains", "0")
        self.add_supply("ucsi-source-psy-USBC000:001", "USB", "1")
        self.add_supply("ucsi-source-psy-USBC000:002", "USB", "0")
        self.add_supply("BAT0", "Battery")
        self.assertEqual(self.run_script().returncode, 0)

    def test_false_when_every_external_supply_is_offline(self):
        self.add_supply("ADP0", "Mains", "0")
        self.add_supply("ucsi-source-psy-USBC000:001", "USB", "0")
        self.add_supply("BAT0", "Battery")
        self.assertEqual(self.run_script().returncode, 1)

    def test_skips_a_supply_without_an_online_file(self):
        self.add_supply("BAT0", "Battery")
        self.add_supply("ADP0", "Mains", "1")
        self.assertEqual(self.run_script().returncode, 0)
