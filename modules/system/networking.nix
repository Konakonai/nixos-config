{ ... }:

{
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

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
