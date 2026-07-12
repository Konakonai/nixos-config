{ hostProfile, pkgs, ... }:

{
  systemd.services.openlist = {
    description = "OpenList Service";
    after = [
      "network-online.target"
      "mihomo.service"
    ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.openlist}/bin/OpenList server --data ${hostProfile.services.openlistDataDir}";
      Restart = "always";
      User = hostProfile.user.userName;
      Group = hostProfile.user.group;
    };
  };
}
