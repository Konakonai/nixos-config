"""Guard routing reachability and app-owned state during configuration updates."""

import importlib.util
import io
import os
from pathlib import Path
import shutil
import stat
import tempfile
import unittest
from unittest.mock import patch

import tomlkit
import yaml

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("noctalia_state", ROOT / "scripts/reconcile-noctalia.py")
state = importlib.util.module_from_spec(spec)
spec.loader.exec_module(state)


class ConfigurationTest(unittest.TestCase):
    def test_proxy_rules_remain_reachable(self):
        config = yaml.safe_load((ROOT / "modules/system/mihomo/config-after-proxies.yaml").read_text())
        preceding = []
        for text in config["rules"]:
            rule = text.split(",")
            self.assertNotIn(rule, preceding, text)
            if rule[0] in ("DOMAIN", "DOMAIN-SUFFIX"):
                for previous in preceding:
                    if previous[0] == "DOMAIN-SUFFIX":
                        self.assertFalse(rule[1] == previous[1] or rule[1].endswith("." + previous[1]),
                                         f"{text} shadowed by {previous}")
            preceding.append(rule)

    def test_noctalia_preserves_gui_fields_and_is_idempotent(self):
        seed = tomlkit.parse(Path(os.environ["NOCTALIA_SEED"]).read_text())
        original = tomlkit.parse('''# GUI settings must survive
[bar.main]
thickness = 57
background_opacity = 0.5
[plugin_settings."mdj2812/mihomo-control"]
port = "9191"
''')
        result = state.reconcile(seed, original)
        self.assertEqual(result["bar"]["main"]["thickness"], 57)
        self.assertEqual(result["bar"]["main"]["background_opacity"], seed["bar"]["main"]["background_opacity"])
        self.assertEqual(result["plugin_settings"]["mdj2812/mihomo-control"]["port"], "9191")
        rendered = tomlkit.dumps(result)
        self.assertIn("# GUI settings must survive", rendered)
        self.assertEqual(tomlkit.dumps(state.reconcile(seed, result)), rendered)

    def test_noctalia_failed_replace_leaves_original_intact(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "settings.toml"
            target.write_text("# original\n")
            with patch.object(Path, "replace", side_effect=OSError("simulated failure")):
                with self.assertRaises(OSError):
                    state.update(Path(os.environ["NOCTALIA_SEED"]), target)
            self.assertEqual(target.read_text(), "# original\n")
            self.assertEqual(list(Path(directory).iterdir()), [target])

    def test_noctalia_skip_does_not_touch_matching_state(self):
        seed_path = Path(os.environ["NOCTALIA_SEED"])
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "settings.toml"
            seed = tomlkit.parse(seed_path.read_text())
            target.write_text(tomlkit.dumps(state.reconcile(seed, tomlkit.parse(seed_path.read_text()))))
            before = target.stat()
            with patch("sys.stderr", io.StringIO()) as err:
                state.update(seed_path, target)
            after = target.stat()
            self.assertIn("noctalia: skip", err.getvalue())
            self.assertEqual(before.st_mtime_ns, after.st_mtime_ns)
            self.assertEqual(before.st_ino, after.st_ino)

    def test_noctalia_uses_theme_cli_when_available(self):
        seed_path = Path(os.environ["NOCTALIA_SEED"])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "settings.toml"
            target.write_text(tomlkit.dumps(tomlkit.parse('''
[bar.main]
thickness = 57
background_opacity = 0.5
''')))
            binary = root / "bin"
            binary.mkdir()
            log = root / "cli.log"
            noctalia = binary / "noctalia"
            noctalia.write_text(
                f"#!{shutil.which('bash')}\n"
                f"echo \"$*\" >> {log}\n"
            )
            noctalia.chmod(noctalia.stat().st_mode | stat.S_IEXEC)
            env = os.environ | {"PATH": f"{binary}:{os.environ['PATH']}"}
            with patch.dict(os.environ, env, clear=False), patch("sys.stderr", io.StringIO()) as err:
                state.update(seed_path, target)
            self.assertIn("noctalia: cli", err.getvalue())
            self.assertTrue(log.exists())
            self.assertIn("theme-mode-set", log.read_text())
            self.assertIn("color-scheme-set", log.read_text())

    def test_niri_color_include_is_optional(self):
        core = (ROOT / "modules/home/niri/core.nix").read_text()
        effects = (ROOT / "modules/home/niri/effects.nix").read_text()
        self.assertIn('path = "noctalia.kdl"', core)
        self.assertIn("optional = true", core)
        self.assertNotIn('include "noctalia.kdl"', effects)
        self.assertIn("validated-config-for", effects)

    def test_niri_coworker_overlay_floats(self):
        core = (ROOT / "modules/home/niri/core.nix").read_text()
        self.assertIn("steam_app_4564320", core)
        self.assertIn("open-floating = true", core)
        self.assertIn("open-fullscreen = false", core)
        self.assertIn("clip-to-geometry = false", core)
        self.assertIn("opacity = 0.99", core)
        self.assertIn("../../../scripts/niri-float-overlay.py", core)
        self.assertIn("niri-float-overlay", core)
        self.assertIn("pkgs.libx11", core)
        self.assertIn("pkgs.libxext", core)
        self.assertNotIn("xorg.libX11", core)
        self.assertNotIn("xorg.libXext", core)
        self.assertTrue((ROOT / "scripts/niri-float-overlay.py").is_file())

    def test_kdeconnect_refresh_modes_are_wired(self):
        hook = os.environ.get("KDECONNECT_NM_HOOK")
        exec_start = os.environ.get("KDECONNECT_REFRESH_EXEC")
        if not hook or not exec_start:
            self.skipTest("generated KDE Connect units are supplied by the configuration check")
        self.assertIn("always", Path(hook).read_text())
        self.assertIn("runuser", Path(hook).read_text())
        self.assertIn("if-unreachable", exec_start)
