{ pkgs, ... }:

{
  systemd.services.openlist = {
    description = "OpenList Service";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.openlist}/bin/OpenList server --data /home/lilya/.config/openlist";
      Restart = "always";
      User = "lilya";
      Group = "users";
    };
  };

  services.printing.enable = true;

  services.mihomo = {
    enable = true;
    tunMode = true;
    configFile = "/home/lilya/.config/mihomo/config.yaml";
    webui = pkgs.metacubexd;
  };
}
