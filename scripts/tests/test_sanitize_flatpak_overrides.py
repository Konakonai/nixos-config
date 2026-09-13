"""Strip empty Flatpak permission tokens without rewriting clean files."""

import importlib.util
from pathlib import Path
from unittest.mock import patch
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "sanitize_flatpak_overrides",
    Path(__file__).resolve().parents[1] / "sanitize-flatpak-overrides.py",
)
sanitize = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sanitize)

WECHAT_OVERRIDE = """[Context]
filesystems=;xdg-config/gtk-3.0:ro;xdg-desktop;xdg-documents
sockets=;wayland;x11
unset-environment=;GLFW_IM_MODULE;INPUT_METHOD;SDL_IM_MODULE

[Environment]
GLFW_IM_MODULE=fcitx
INPUT_METHOD=
QT_QPA_PLATFORM=xcb

[Session Bus Policy]
org.fcitx.Fcitx5=talk
"""

CLEAN_OVERRIDE = """[Context]
filesystems=xdg-config/gtk-3.0:ro;xdg-desktop;xdg-documents
sockets=wayland;x11
unset-environment=GLFW_IM_MODULE;INPUT_METHOD;SDL_IM_MODULE

[Environment]
GLFW_IM_MODULE=fcitx
INPUT_METHOD=
QT_QPA_PLATFORM=xcb

[Session Bus Policy]
org.fcitx.Fcitx5=talk
"""


class SanitizeFlatpakOverridesTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.directory = self.root / "overrides"
        self.directory.mkdir()

    def test_leading_empty_tokens_are_removed_and_other_keys_kept(self):
        self.assertEqual(sanitize.sanitize_text(WECHAT_OVERRIDE), CLEAN_OVERRIDE)

    def test_empty_only_list_drops_the_key(self):
        self.assertEqual(
            sanitize.sanitize_text("[Context]\nsockets=;\nfilesystems=wayland\n"),
            "[Context]\nfilesystems=wayland\n",
        )

    def test_missing_directory_is_a_no_op(self):
        self.assertEqual(sanitize.sanitize_dir(self.root / "missing"), [])

    def test_dirty_file_is_rewritten_and_clean_file_is_left_alone(self):
        dirty = self.directory / "com.tencent.WeChat"
        clean = self.directory / "com.qq.QQ"
        dirty.write_text(WECHAT_OVERRIDE)
        clean.write_text(CLEAN_OVERRIDE)
        before = clean.stat()
        rewritten = sanitize.sanitize_dir(self.directory)
        self.assertEqual(rewritten, [dirty])
        self.assertEqual(dirty.read_text(), CLEAN_OVERRIDE)
        after = clean.stat()
        self.assertEqual(before.st_mtime_ns, after.st_mtime_ns)
        self.assertEqual(before.st_ino, after.st_ino)
        self.assertEqual(sanitize.sanitize_dir(self.directory), [])

    def test_failed_replace_leaves_original_intact(self):
        target = self.directory / "com.tencent.WeChat"
        target.write_text(WECHAT_OVERRIDE)
        with patch.object(Path, "replace", side_effect=OSError("simulated failure")):
            with self.assertRaises(OSError):
                sanitize.sanitize_file(target)
        self.assertEqual(target.read_text(), WECHAT_OVERRIDE)
        self.assertEqual(list(self.directory.iterdir()), [target])

    def test_cli_uses_the_given_directory(self):
        dirty = self.directory / "com.tencent.WeChat"
        dirty.write_text(WECHAT_OVERRIDE)
        self.assertEqual(sanitize.main([str(self.directory)]), 0)
        self.assertEqual(dirty.read_text(), CLEAN_OVERRIDE)
