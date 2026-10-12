"""Guard Mihomo rule reachability and ordering."""

from pathlib import Path
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[2]


class ConfigurationTest(unittest.TestCase):
    def test_proxy_rules_remain_reachable(self):
        config = yaml.safe_load((ROOT / "modules/system/mihomo/config-after-proxies.yaml").read_text())
        groups = {group["name"] for group in config["proxy-groups"]} | {"DIRECT", "REJECT"}
        preceding = []
        for text in config["rules"]:
            rule = text.split(",")
            self.assertNotIn(rule, preceding, text)
            self.assertIn(rule[-1], groups, text)
            if rule[0] in ("DOMAIN", "DOMAIN-SUFFIX"):
                for previous in preceding:
                    if previous[0] == "DOMAIN-SUFFIX":
                        self.assertFalse(rule[1] == previous[1] or rule[1].endswith("." + previous[1]),
                                         f"{text} shadowed by {previous}")
            preceding.append(rule)

    def test_geosite_categories_sit_between_pins_and_fallbacks(self):
        config = yaml.safe_load((ROOT / "modules/system/mihomo/config-after-proxies.yaml").read_text())
        rules = config["rules"]
        first_geosite = next(i for i, r in enumerate(rules) if r.startswith("GEOSITE,"))
        self.assertLess(rules.index("DOMAIN-SUFFIX,cn,DIRECT"), first_geosite)
        self.assertEqual(rules[-3:], ["GEOIP,CN,DIRECT", "GEOIP,PRIVATE,DIRECT", "MATCH,Default Proxy"])
        self.assertEqual(rules[-5:-3], ["GEOSITE,private,DIRECT", "GEOSITE,cn,DIRECT"])
