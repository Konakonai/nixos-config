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

    def test_subscription_host_resolves_directly_over_doh(self):
        servers = self.dns["nameserver-policy"]["update.glados-config.com"]
        self.assertIn("https://223.5.5.5/dns-query", servers)
        for server in servers:
            self.assertTrue(server.startswith("https://"), server)
            self.assertNotIn("1.1.1.1", server)

    def test_captive_portal_probes_resolve_locally_and_bypass_proxy(self):
        config = yaml.safe_load(AFTER.read_text())
        policy = config["dns"]["nameserver-policy"]
        fake_ip_filter = config["dns"]["fake-ip-filter"]
        rules = config["rules"]
        first_geosite = next(
            i for i, r in enumerate(rules) if r.startswith("GEOSITE,") and not r.endswith(",Ad Block")
        )
        for host in (
            "firefox-portal-detection.com",
            "detectportal.firefox.com",
            "nmcheck.gnome.org",
            "captive.apple.com",
        ):
            self.assertIn("system://", policy[host], host)
            self.assertNotIn(host, fake_ip_filter, host)
            self.assertLess(rules.index(f"DOMAIN,{host},DIRECT"), first_geosite, host)

    def test_campus_portal_excluded_from_tun_without_excluding_rfc1918_dns(self):
        excluded = yaml.safe_load(AFTER.read_text())["tun"]["route-exclude-address"]
        self.assertIn("10.2.5.251/32", excluded)
        for broad in ("10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12"):
            self.assertNotIn(broad, excluded)
