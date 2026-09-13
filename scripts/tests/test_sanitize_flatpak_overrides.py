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

    def test_drop_env_removes_dpi_leftovers_and_conflicting_unsets(self):
        leftover = """[Context]
filesystems=xdg-config/gtk-3.0:ro
sockets=wayland;x11
unset-environment=GLFW_IM_MODULE;INPUT_METHOD;SDL_IM_MODULE

[Environment]
FCITX_QT_USE_SYNC=1
GLFW_IM_MODULE=fcitx
INPUT_METHOD=
QT_AUTO_SCREEN_SCALE_FACTOR=1
QT_ENABLE_HIGHDPI_SCALING=1
QT_QPA_PLATFORM=xcb
QT_SCALE_FACTOR_ROUNDING_POLICY=PassThrough
SDL_IM_MODULE=fcitx
"""
        cleaned = sanitize.sanitize_text(
            leftover,
            drop_env=(
                "QT_ENABLE_HIGHDPI_SCALING",
                "QT_SCALE_FACTOR_ROUNDING_POLICY",
                "FCITX_QT_USE_SYNC",
                "INPUT_METHOD",
            ),
            drop_unset=("GLFW_IM_MODULE", "SDL_IM_MODULE", "INPUT_METHOD"),
        )
        self.assertEqual(
            cleaned,
            """[Context]
filesystems=xdg-config/gtk-3.0:ro
sockets=wayland;x11

[Environment]
GLFW_IM_MODULE=fcitx
QT_AUTO_SCREEN_SCALE_FACTOR=1
QT_QPA_PLATFORM=xcb
SDL_IM_MODULE=fcitx
""",
        )

    def test_cli_drop_flags_leave_unrelated_overrides_alone(self):
        wechat = self.directory / "com.tencent.WeChat"
        qq = self.directory / "com.qq.QQ"
        wechat.write_text(
            "[Environment]\nQT_ENABLE_HIGHDPI_SCALING=1\nQT_QPA_PLATFORM=xcb\n"
        )
        qq.write_text("[Environment]\nQT_QPA_PLATFORM=wayland\n")
        before = qq.stat()
        self.assertEqual(
            sanitize.main(
                [
                    "--drop-env",
                    "QT_ENABLE_HIGHDPI_SCALING",
                    str(self.directory),
                ]
            ),
            0,
        )
        self.assertEqual(wechat.read_text(), "[Environment]\nQT_QPA_PLATFORM=xcb\n")
        after = qq.stat()
        self.assertEqual(before.st_mtime_ns, after.st_mtime_ns)
        self.assertEqual(before.st_ino, after.st_ino)
