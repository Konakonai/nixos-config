"""Split DNS must send foreign lookups through Default Proxy."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
AFTER = ROOT / "modules/system/mihomo/config-after-proxies.yaml"


def dns_block(text: str) -> str:
    start = text.index("\ndns:\n") + 1
    end = text.index("\ntun:\n", start)
    return text[start:end]


def mapping_list(block: str, key: str) -> str:
    needle = f"\n  {key}:\n"
    start = block.index(needle) + 1
    rest = block[start:]
    lines = rest.splitlines()
    collected = [lines[0]]
    for line in lines[1:]:
        if line.startswith("  ") and not line.startswith("    ") and not line.startswith("  -"):
            break
        collected.append(line)
    return "\n".join(collected)


class DnsLeakPreventionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dns = dns_block(AFTER.read_text())

    def test_foreign_lookups_use_proxied_doh(self):
        self.assertIn("respect-rules: true", self.dns)
        nameserver = mapping_list(self.dns, "nameserver")
        self.assertIn("1.1.1.1", nameserver)
        self.assertIn("8.8.8.8", nameserver)
        self.assertIn("#Default Proxy", nameserver)
        self.assertNotIn("114.114.114.114", nameserver)
        self.assertNotIn("119.29.29.29", nameserver)
        self.assertNotIn("223.5.5.5", nameserver)
        self.assertNotIn("alidns.com", nameserver)
        self.assertNotIn("doh.pub", nameserver)

    def test_cn_and_private_keep_direct_resolvers(self):
        self.assertIn("geosite:cn", self.dns)
        self.assertIn("geosite:private", self.dns)
        policy = mapping_list(self.dns, "nameserver-policy")
        self.assertIn("114.114.114.114", policy)
        self.assertIn("223.5.5.5", policy)
        self.assertIn("system://", policy)

    def test_proxy_node_bootstrap_does_not_use_tun_dns(self):
        servers = mapping_list(self.dns, "proxy-server-nameserver")
        self.assertIn("https://223.5.5.5/dns-query", servers)
        # Plain UDP/53 can be hijacked by an upstream fake-ip gateway.
        for line in servers.splitlines()[1:]:
            self.assertIn("https://", line)
        self.assertNotIn("null", servers)
        self.assertNotIn("1.1.1.1", servers)
