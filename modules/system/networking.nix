{ ... }:

{
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # Campus Wi-Fi assigns a CERNET GUA. WebRTC advertises it as a host
  # candidate and bypasses the mihomo TUN. Keep host IPv6 off.
  networking.enableIPv6 = false;
  networking.networkmanager.connectionConfig = {
    "ipv6.method" = "disabled";
  };

  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "mihomo" ];
    checkReversePath = false;

    # OpenList, LocalSend and the Mihomo mixed port are intentionally reachable
    # on the LAN. The mixed port requires the `authentication` credentials kept
    # in the encrypted proxies fragment.
    allowedTCPPorts = [
      5244
      7890
      53317
    ];

    # LocalSend multicast discovery and the Mihomo mixed port.
    allowedUDPPorts = [
      7890
      53317
    ];

    # programs.kdeconnect owns its TCP/UDP port ranges.

    # NetworkManager Wi-Fi hotspot (shared mode, LTE uplink): its dnsmasq
    # serves DHCP and DNS on 10.42.0.1, and nixos-fw would drop both. Only
    # that dnsmasq listens on these ports here, so nothing is exposed on
    # other Wi-Fi networks while the hotspot is off.
    interfaces.wlp0s20f3 = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [
        53
        67
      ];
    };
  };
}
