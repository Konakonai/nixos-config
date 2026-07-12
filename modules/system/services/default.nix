{ pkgs, ... }:

{
  imports = [
    ../mihomo.nix
    ./openlist.nix
  ];

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
