"""Policy groups pick subscription nodes by tag, never by hard-coded name."""

from pathlib import Path
import re
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[2]
AFTER = ROOT / "modules/system/mihomo/config-after-proxies.yaml"

PROVIDER = "glados"
BUILTINS = {"DIRECT", "REJECT"}
# Self-hosted nodes defined statically in the encrypted fragment.
STATIC_NODES = {"IN-NexIP-Sticky", "IN-NexIP-Rotating"}


class ProxyGroupTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.groups = yaml.safe_load(AFTER.read_text())["proxy-groups"]
        cls.by_name = {g["name"]: g for g in cls.groups}

    def test_static_members_are_groups_or_self_hosted(self):
        allowed = set(self.by_name) | BUILTINS | STATIC_NODES
        for group in self.groups:
            for member in group.get("proxies", []):
                self.assertIn(member, allowed, f"{group['name']} hard-codes {member}")

    def test_every_group_has_members(self):
        for group in self.groups:
            self.assertTrue(group.get("proxies") or group.get("use"), group["name"])

    def test_filters_only_on_provider_groups(self):
        for group in self.groups:
            if "use" in group:
                self.assertEqual(group["use"], [PROVIDER], group["name"])
                re.compile(group["filter"])
            else:
                self.assertNotIn("filter", group, group["name"])

    def test_unthrottled_nodes_precede_auto_for_downloads(self):
        self.assertEqual(self.by_name["Download-Auto"]["proxies"][0], "Unthrottled")


if __name__ == "__main__":
    unittest.main()
