"""Replace user theme directories without deleting the live copy first."""

from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/copy-theme-dir.sh"


class CopyThemeDirTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.src = self.root / "src"
        self.dst = self.root / "dst"
        self.src.mkdir()
        (self.src / "index.theme").write_text("name=nix\n")

    def copy(self, src=None, dst=None):
        return subprocess.run(
            ["bash", str(SCRIPT), str(src or self.src), str(dst or self.dst)],
            capture_output=True,
            text=True,
        )

    def test_first_copy_is_idempotent_for_the_same_source(self):
        self.assertEqual(self.copy().returncode, 0)
        self.assertEqual((self.dst / "index.theme").read_text(), "name=nix\n")
        self.assertEqual((self.dst / ".nix-source").read_text(), f"{self.src}\n")
        (self.dst / "user-file").write_text("keep\n")
        self.assertEqual(self.copy().returncode, 0)
        self.assertEqual((self.dst / "user-file").read_text(), "keep\n")

    def test_source_change_replaces_without_leaving_staging(self):
        self.assertEqual(self.copy().returncode, 0)
        new = self.root / "src2"
        new.mkdir()
        (new / "index.theme").write_text("name=next\n")
        self.assertEqual(self.copy(src=new).returncode, 0)
        self.assertEqual((self.dst / "index.theme").read_text(), "name=next\n")
        self.assertFalse(list(self.root.glob("dst.staging.*")))
        self.assertFalse(list(self.root.glob("dst.previous.*")))

    def test_symlink_destination_is_left_alone(self):
        target = self.root / "real"
        target.mkdir()
        self.dst.symlink_to(target)
        self.assertEqual(self.copy().returncode, 0)
        self.assertTrue(self.dst.is_symlink())
        self.assertFalse((target / "index.theme").exists())
