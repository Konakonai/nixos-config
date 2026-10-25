{ ... }:

{
  # Lets the phone reach Jellyfin away from home: the LTE address is
  # carrier-internal and host IPv6 is off, so nothing can dial in directly.
  #
  # Tailscale's ip rules (5210-5270) sit ahead of mihomo's (9000+), so both
  # tailnet traffic and tailscaled's own fwmarked packets bypass the mihomo
  # TUN without changes there. DNS stays with mihomo: MagicDNS would replace
  # the resolver that dns-hijack relies on.
  services.tailscale = {
    enable = true;
    openFirewall = true;
    extraSetFlags = [ "--accept-dns=false" ];
  };

  # The same fwmark bypass sends the control plane and DERP straight out, and
  # controlplane.tailscale.com does not answer from here, so `tailscale up`
  # hangs. tailscaled honours HTTPS_PROXY for those TCP connections; the
  # mixed port skips auth for loopback. WireGuard UDP still goes direct.
  systemd.services.tailscaled = {
    after = [ "mihomo.service" ];
    environment.HTTPS_PROXY = "http://127.0.0.1:7890";
  };
}
