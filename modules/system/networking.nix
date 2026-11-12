{ ... }:

{
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # NixOS restarts polkit whenever system.path changes, and upstream
  # ModemManager.service has Requires=polkit.service, so every rebuild that
  # touched system packages stopped ModemManager too. Its MBIM teardown then
  # hangs until the 90 s SIGKILL and LTE drops. Rules changes still reload
  # polkit; a new polkit or new packages' actions take effect after a reboot.
  systemd.services.polkit.restartIfChanged = false;

  # Host IPv6 is on so Tailscale can reach the phone directly over the LTE
  # and campus GUAs (both sides sit behind symmetric IPv4 NAT). mihomo's TUN
  # carries IPv6 like IPv4, so the remaining leak is WebRTC listing the GUA
  # as a host candidate. Zen drops host candidates (modules/home/zen.nix);
  # Chromium and Brave only expose the default-route interface, which is the
  # TUN, and STUN is forced through the proxy by the mihomo rules.
  environment.etc =
    let
      webrtcPolicy = builtins.toJSON {
        WebRtcIPHandlingPolicy = "default_public_interface_only";
      };
    in
    {
      "chromium/policies/managed/webrtc.json".text = webrtcPolicy;
      "brave/policies/managed/webrtc.json".text = webrtcPolicy;
    };

  # Hotspot clients are routed into the mihomo TUN, and mihomo's replies come
  # back in on that interface. Without forwarding on it the kernel drops them
  # and clients get DHCP and DNS but no traffic. udev applies this when the
  # TUN appears; enabling it on `all` would make the host route for any LAN.
  boot.kernel.sysctl."net.ipv4.conf.mihomo.forwarding" = 1;

  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "mihomo" ];
    checkReversePath = false;

    # Nothing is opened on every interface: the LTE uplink has a public IPv6
    # address (see above), so a globally allowed port is reachable from the
    # internet there. LAN services are listed under the Wi-Fi interface below.

    # programs.kdeconnect owns its TCP/UDP port ranges.

    # Only Jellyfin is opened to the tailnet, for the phone away from home.
    interfaces.tailscale0.allowedTCPPorts = [ 8096 ];

    # NetworkManager Wi-Fi hotspot (shared mode, LTE uplink): its dnsmasq
    # serves DHCP and DNS on 10.42.0.1, and nixos-fw would drop both. Only
    # that dnsmasq listens on 53/67 here, so they expose nothing on other
    # Wi-Fi networks while the hotspot is off.
    #
    # Jellyfin (8096) is for the phone, which joins either the hotspot or the
    # same Wi-Fi, so it is opened on the Wi-Fi interface only and stays closed
    # on the LTE uplink. The Calibre content server (8080) follows the same
    # rule: it has no authentication by default.
    #
    # OpenList (5244), LocalSend (53317, UDP for its multicast discovery) and
    # the Mihomo mixed port (7890) are for other devices on the same Wi-Fi or
    # the hotspot. The mixed port requires the `authentication` credentials
    # kept in the encrypted proxies fragment.
    interfaces.wlp0s20f3 = {
      allowedTCPPorts = [
        53
        5244
        7890
        8080
        8096
        53317
      ];
      allowedUDPPorts = [
        53
        67
        7890
        53317
      ];
    };
  };
}
