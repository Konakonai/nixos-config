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

    allowedTCPPorts = [ 5244 ];

    allowedTCPPortRanges = [
      { from = 1714; to = 1764; }
    ];

    allowedUDPPortRanges = [
      { from = 1714; to = 1764; }
    ];
  };
}
