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
        miwifi = self.rules.index("DOMAIN-SUFFIX,miwifi.com,DIRECT")
        bili = self.rules.index("DOMAIN-SUFFIX,bilibili.com,DIRECT")
        geoip = self.rules.index("GEOIP,CN,DIRECT")
        self.assertLess(stun, miwifi)
        self.assertLess(stun, bili)
        self.assertLess(stun, geoip)
        self.assertLess(port, miwifi)
        self.assertLess(port, geoip)

    def test_miwifi_fakeip_filter_does_not_cover_stun(self):
        start = self.text.index("\n  fake-ip-filter:\n")
        end = self.text.index("\n  fake-ip-filter-mode:", start)
        block = self.text[start:end]
        self.assertNotIn("+.miwifi.com", block)
        self.assertIn("router.miwifi.com", block)
