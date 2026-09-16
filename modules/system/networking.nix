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

    # OpenList and LocalSend are intentionally reachable on the LAN.
    allowedTCPPorts = [
      5244
      53317
    ];

    # LocalSend multicast discovery.
    allowedUDPPorts = [ 53317 ];

    # programs.kdeconnect owns its TCP/UDP port ranges.
  };
}
