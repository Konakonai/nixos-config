"""STUN/WebRTC must not match CN DIRECT rules first."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
AFTER = ROOT / "modules/system/mihomo/config-after-proxies.yaml"


class StunProxyOrderTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = AFTER.read_text()
        start = cls.text.index("\nrules:\n") + 1
        cls.rules = cls.text[start:]

    def test_stun_rules_precede_cn_direct(self):
        stun = self.rules.index("DOMAIN-KEYWORD,stun,Default Proxy")
        port = self.rules.index("DST-PORT,3478,Default Proxy")
        cn_suffix = self.rules.index("DOMAIN-SUFFIX,cn,DIRECT")
        geosite_cn = self.rules.index("GEOSITE,cn,DIRECT")
        geoip = self.rules.index("GEOIP,CN,DIRECT")
        for direct in (cn_suffix, geosite_cn, geoip):
            self.assertLess(stun, direct)
            self.assertLess(port, direct)

    def test_ip_check_sites_precede_cn_direct(self):
        # Chinese IP-echo sites are listed in geosite:cn; they must still go
        # through the proxy so the real WAN address is not revealed.
        geosite_cn = self.rules.index("GEOSITE,cn,DIRECT")
        for site in ("ip138.com", "ipip.net", "cip.cc", "myip.la"):
            self.assertLess(self.rules.index(f"DOMAIN-SUFFIX,{site},Default Proxy"), geosite_cn)

    def test_miwifi_fakeip_filter_does_not_cover_stun(self):
        start = self.text.index("\n  fake-ip-filter:\n")
        end = self.text.index("\n  fake-ip-filter-mode:", start)
        block = self.text[start:end]
        self.assertNotIn("+.miwifi.com", block)
        self.assertIn("router.miwifi.com", block)
