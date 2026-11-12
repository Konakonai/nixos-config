"""STUN/WebRTC must not match CN DIRECT rules first."""

from pathlib import Path
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[2]
AFTER = ROOT / "modules/system/mihomo/config-after-proxies.yaml"


class StunProxyOrderTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        config = yaml.safe_load(AFTER.read_text())
        cls.rules = config["rules"]
        cls.fake_ip_filter = config["dns"]["fake-ip-filter"]

    def position(self, prefix):
        # Prefix, not equality: a rule may carry options such as no-resolve.
        for index, rule in enumerate(self.rules):
            if rule.startswith(prefix):
                return index
        self.fail(f"no rule starts with {prefix}")

    def test_stun_rules_precede_cn_direct(self):
        stun = self.position("DOMAIN-KEYWORD,stun,Default Proxy")
        port = self.position("DST-PORT,3478,Default Proxy")
        for direct in ("DOMAIN-SUFFIX,cn,DIRECT", "GEOSITE,cn,DIRECT", "GEOIP,CN,DIRECT"):
            self.assertLess(stun, self.position(direct))
            self.assertLess(port, self.position(direct))

    def test_ip_check_sites_precede_cn_direct(self):
        # Chinese IP-echo sites are listed in geosite:cn; they must still go
        # through the proxy so the real WAN address is not revealed.
        geosite_cn = self.position("GEOSITE,cn,DIRECT")
        for site in ("ip138.com", "ipip.net", "cip.cc", "myip.la"):
            self.assertLess(self.position(f"DOMAIN-SUFFIX,{site},Default Proxy"), geosite_cn)

    def test_miwifi_fakeip_filter_does_not_cover_stun(self):
        self.assertNotIn("+.miwifi.com", self.fake_ip_filter)
        self.assertIn("router.miwifi.com", self.fake_ip_filter)
