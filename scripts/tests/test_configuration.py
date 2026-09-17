"""Guard routing reachability and cross-module contracts."""

import os
from pathlib import Path
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[2]


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

    def test_niri_color_include_is_optional(self):
        core = (ROOT / "modules/home/niri/core.nix").read_text()
        effects = (ROOT / "modules/home/niri/effects.nix").read_text()
        self.assertIn('path = "noctalia.kdl"', core)
        self.assertIn("optional = true", core)
        self.assertNotIn('include "noctalia.kdl"', effects)
        self.assertIn("validated-config-for", effects)

    def test_kdeconnect_refresh_modes_are_wired(self):
        hook = os.environ.get("KDECONNECT_NM_HOOK")
        exec_start = os.environ.get("KDECONNECT_REFRESH_EXEC")
        if not hook or not exec_start:
            self.skipTest("generated KDE Connect units are supplied by the configuration check")
        self.assertIn("always", Path(hook).read_text())
        self.assertIn("runuser", Path(hook).read_text())
        self.assertIn("if-unreachable", exec_start)
