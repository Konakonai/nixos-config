"""Policy groups pick subscription nodes by tag, never by hard-coded name."""

from pathlib import Path
import re
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[2]
AFTER = ROOT / "modules/system/mihomo/config-after-proxies.yaml"

PROVIDER = "glados"
FIXED_IP_PROVIDER = "glados-fixed-ip"
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
                provider = FIXED_IP_PROVIDER if group["name"] in {
                    "US Fixed IP", "Google-US", "TW Fixed IP"
                } else PROVIDER
                self.assertEqual(group["use"], [provider], group["name"])
                re.compile(group["filter"])
            else:
                self.assertNotIn("filter", group, group["name"])

    def test_unthrottled_nodes_precede_auto_for_downloads(self):
        self.assertEqual(self.by_name["Download-Auto"]["proxies"][0], "Unthrottled")

    def test_google_account_domains_share_one_exit(self):
        # Google binds session tokens to the client IP ("<ip> != <ip>").
        # Anonymous bulk downloads may still take a download group.
        downloads = {"storage.googleapis.com"}
        rules = yaml.safe_load(AFTER.read_text())["rules"]
        for rule in rules:
            kind, payload, target = (rule.split(",") + [""])[:3]
            if kind not in {"DOMAIN-SUFFIX", "DOMAIN-KEYWORD", "GEOSITE"}:
                continue
            if payload in downloads or not re.search(r"google|gstatic|gmail", payload):
                continue
            self.assertEqual(target, "Google", rule)


if __name__ == "__main__":
    unittest.main()
