"""Guard routing reachability and app-owned state during configuration updates."""

import importlib.util
import os
from pathlib import Path
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

    def test_niri_color_include_is_optional(self):
        core = (ROOT / "modules/home/niri/core.nix").read_text()
        effects = (ROOT / "modules/home/niri/effects.nix").read_text()
        self.assertIn('path = "noctalia.kdl"', core)
        self.assertIn("optional = true", core)
        self.assertNotIn('include "noctalia.kdl"', effects)
        self.assertIn("validated-config-for", effects)
