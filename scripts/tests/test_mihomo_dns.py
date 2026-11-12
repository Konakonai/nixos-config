"""Split DNS must send foreign lookups through Default Proxy."""

from pathlib import Path
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[2]
AFTER = ROOT / "modules/system/mihomo/config-after-proxies.yaml"


class DnsLeakPreventionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dns = yaml.safe_load(AFTER.read_text())["dns"]

    def test_foreign_lookups_use_proxied_doh(self):
        self.assertIs(self.dns["respect-rules"], True)
        nameserver = " ".join(self.dns["nameserver"])
        self.assertIn("1.1.1.1", nameserver)
        self.assertIn("8.8.8.8", nameserver)
        self.assertIn("#Default Proxy", nameserver)
        for direct in ("114.114.114.114", "119.29.29.29", "223.5.5.5", "alidns.com", "doh.pub"):
            self.assertNotIn(direct, nameserver)

    def test_cn_and_private_keep_direct_resolvers(self):
        policy = self.dns["nameserver-policy"]
        self.assertIn("114.114.114.114", policy["geosite:cn"])
        self.assertIn("223.5.5.5", policy["geosite:cn"])
        self.assertIn("system://", policy["geosite:private"])

    def test_proxy_node_bootstrap_does_not_use_tun_dns(self):
        servers = self.dns["proxy-server-nameserver"]
        self.assertIn("https://223.5.5.5/dns-query", servers)
        for server in servers:
            self.assertIsInstance(server, str)
            # Plain UDP/53 can be hijacked by an upstream fake-ip gateway.
            self.assertTrue(server.startswith("https://"), server)
            self.assertNotIn("1.1.1.1", server)
