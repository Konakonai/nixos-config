{ pkgs, ... }:

{
  imports = [
    ./mihomo.nix
  ];

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
      ExecStart = "${pkgs.openlist}/bin/OpenList server --data /home/lilya/.config/openlist";
      Restart = "always";
      User = "lilya";
      Group = "users";
    };
  };

  services.printing.enable = true;

  services.kmscon = {
    enable = true;
    hwRender = true;
    extraConfig = ''
      font-name=Noto Sans CJK SC
      font-size=16
      multi-monitor=largest
    '';
  };
}
