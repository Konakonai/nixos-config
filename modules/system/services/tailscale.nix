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
}
