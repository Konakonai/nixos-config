"""Test turbo/PCIe policy ownership and restoration without touching hardware."""

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

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

    def test_match_rules_are_scoped_to_the_two_services(self):
        rules = cpu_policy.match_rules()
        self.assertEqual(len(rules), 2 * len(cpu_policy.SERVICES))
        for name, path in cpu_policy.SERVICES.items():
            self.assertTrue(any(f"path='{path}'" in rule for rule in rules))
            self.assertTrue(any(f"arg0='{name}'" in rule for rule in rules))

    def test_locked_aspm_policy_does_not_block_turbo(self):
        real_write = cpu_policy.write

        def write(path, value):
            if path == self.pcie_aspm:
                raise PermissionError("locked by firmware")
            real_write(path, value)

        with mock.patch.object(cpu_policy, "write", write):
            self.apply(True, "power-saver")
            self.assertEqual(self.turbo.read_text(), "1\n")
            self.assertTrue(self.saved.exists())
            self.apply(False, "power-saver")
        self.assertEqual(self.turbo.read_text(), "0\n")
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
