{ pkgs, ... }:

{
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # NixOS leaves ModemManager D-Bus-activated only (WantedBy is empty), and
  # NetworkManager does not trigger D-Bus activation on its own. Without this
  # rule, plugging in an external USB LTE modem sits idle until an unrelated
  # client pokes org.freedesktop.ModemManager1.
  #
  # Numbered 68- so MTP_NO_PROBE runs ahead of 69-libmtp.rules: the Lenovo
  # MDM9207 dongle advertises bDeviceClass=00 and "MDM9207-MTP", causing
  # mtp-probe to scan it twice on every plug-in.
  services.udev.packages = [
    (pkgs.writeTextDir "lib/udev/rules.d/68-lte-modem.rules" ''
      ACTION=="add", SUBSYSTEM=="usbmisc", KERNEL=="cdc-wdm*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="ModemManager.service"
      ACTION=="add|bind", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="17ef", ATTR{idProduct}=="7240", ENV{MTP_NO_PROBE}="1"
    '')
  ];

  # NixOS restarts polkit whenever system.path changes, and upstream
  # ModemManager.service has Requires=polkit.service, so every rebuild that
  # touched system packages stopped ModemManager too. Its MBIM teardown then
  # hangs until the 90 s SIGKILL and LTE drops. Rules changes still reload
  # polkit; a new polkit or new packages' actions take effect after a reboot.
  systemd.services.polkit.restartIfChanged = false;

  # Host IPv6 is on so Tailscale can reach the phone directly over the LTE
  # and campus GUAs (both sides sit behind symmetric IPv4 NAT). mihomo's TUN
  # carries IPv6 like IPv4, so the remaining leak is WebRTC listing the GUA
  # as a host candidate. Zen drops host candidates (modules/user/apps/zen.nix);
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

    # Jellyfin is opened to the tailnet for the phone away from home
    # (NectarLink adds its port in modules/services/nectarlink.nix).
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

  # Tailscale: lets the phone reach Jellyfin and NectarLink away from home.
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
