"""Test turbo ownership and restoration without touching hardware."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("turbo", Path(__file__).resolve().parents[1] / "power-saver-turbo.py")
turbo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(turbo)


class TurboTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.knob = Path(temp.name) / "no_turbo"
        self.saved = Path(temp.name) / "previous"
        self.knob.write_text("0\n")

    def apply(self, battery, profile):
        turbo.apply(battery, profile, self.knob, self.saved)

    def test_battery_saver_then_ac(self):
        self.apply(True, "power-saver")
        self.apply(True, "power-saver")
        self.assertEqual(self.knob.read_text().strip(), "1")
        self.assertEqual(self.saved.read_text().strip(), "0")
        self.apply(False, "power-saver")
        self.assertEqual(self.knob.read_text().strip(), "0")
        self.assertFalse(self.saved.exists())

    def test_mode_change_restores(self):
        self.apply(True, "power-saver")
        self.apply(True, "balanced")
        self.assertEqual(self.knob.read_text().strip(), "0")

    def test_preserve_preexisting_turbo_disable(self):
        self.knob.write_text("1\n")
        self.apply(True, "power-saver")
        self.apply(True, "performance")
        self.assertEqual(self.knob.read_text().strip(), "1")

    def test_unowned_state_is_untouched(self):
        self.knob.write_text("1\n")
        self.apply(False, "balanced")
        self.assertEqual(self.knob.read_text().strip(), "1")
        self.assertFalse(self.saved.exists())

    def test_service_stop_restores(self):
        self.apply(True, "power-saver")
        turbo.restore(self.knob, self.saved)
        self.assertEqual(self.knob.read_text().strip(), "0")


if __name__ == "__main__":
    unittest.main()
