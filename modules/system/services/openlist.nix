{ hostProfile, pkgs, ... }:

{
  systemd.services.openlist = {
    description = "OpenList Service";
    after = [ "mihomo.service" ];
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
