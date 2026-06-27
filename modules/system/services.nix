{ hostProfile, pkgs, ... }:

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
      ExecStart = "${pkgs.openlist}/bin/OpenList server --data ${hostProfile.services.openlistDataDir}";
      Restart = "always";
      User = hostProfile.user.userName;
      Group = hostProfile.user.group;
    };
  };

  services.printing.enable = true;

  services.kmscon = {
    enable = true;
    hwRender = true;
    fonts = [
      {
        name = "Noto Sans CJK SC";
        package = pkgs.noto-fonts-cjk-sans;
      }
    ];
    term = "xterm-256color";
    useXkbConfig = true;
    extraConfig = ''
      font-size=16
      multi-monitor=largest
    '';
  };
}
