"""Test turbo/PCIe policy ownership and restoration without touching hardware."""

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "cpu_policy", Path(__file__).resolve().parents[1] / "power-saver-cpu.py"
)
cpu_policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cpu_policy)


class CpuPolicyTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        self.turbo = root / "no_turbo"
        self.turbo.write_text("0\n")
        self.saved = root / "previous.json"
        self.pcie_aspm = root / "pcie_aspm_policy"
        self.pcie_aspm.write_text("[default] performance powersave powersupersave\n")

    def apply(self, battery, profile):
        cpu_policy.apply(
            battery,
            profile,
            self.turbo,
            self.saved,
            self.pcie_aspm,
        )

    def test_battery_saver_applies_and_ac_restores(self):
        self.apply(True, "power-saver")
        self.assertEqual(self.turbo.read_text().strip(), "1")
        self.assertEqual(self.pcie_aspm.read_text().strip(), "powersupersave")
        self.apply(False, "power-saver")
        self.assertEqual(self.turbo.read_text().strip(), "0")
        self.assertEqual(self.pcie_aspm.read_text().strip(), "default")
        self.assertFalse(self.saved.exists())

    def test_mode_change_restores(self):
        self.apply(True, "power-saver")
        self.apply(True, "balanced")
        self.assertEqual(self.turbo.read_text().strip(), "0")
        self.assertEqual(self.pcie_aspm.read_text().strip(), "default")

    def test_repeated_event_keeps_original_snapshot(self):
        self.apply(True, "power-saver")
        original = json.loads(self.saved.read_text())
        self.apply(True, "power-saver")
        self.assertEqual(json.loads(self.saved.read_text()), original)

    def test_unowned_state_is_untouched(self):
        self.turbo.write_text("1\n")
        self.apply(False, "balanced")
        self.assertEqual(self.turbo.read_text().strip(), "1")
        self.assertFalse(self.saved.exists())

    def test_service_stop_restores(self):
        self.apply(True, "power-saver")
        cpu_policy.restore(self.turbo, self.saved, self.pcie_aspm)
        self.assertEqual(self.turbo.read_text().strip(), "0")
        self.assertEqual(self.pcie_aspm.read_text().strip(), "default")


if __name__ == "__main__":
    unittest.main()
