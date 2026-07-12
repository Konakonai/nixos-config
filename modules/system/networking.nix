{ ... }:

{
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "mihomo" ];
    checkReversePath = false;

    extraReversePathFilterRules = ''
      iifname { "mihomo" } accept comment "trusted interface"
    '';

    # OpenList and LocalSend are intentionally reachable on the LAN.
    allowedTCPPorts = [
      5244
      53317
    ];

    # LocalSend multicast discovery.
    allowedUDPPorts = [ 53317 ];

    allowedTCPPortRanges = [
      { from = 1714; to = 1764; }
    ];

    allowedUDPPortRanges = [
      { from = 1714; to = 1764; }
    ];
  };
}
