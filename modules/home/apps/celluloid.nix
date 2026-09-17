{ pkgs, ... }:

{
  dconf.settings."io/github/celluloid-player/celluloid" = {
    mpv-config-enable = false;
  };

  xdg.configFile = {
    # Celluloid 脚本
    "celluloid/scripts/autoload.lua".source =
      "${pkgs.mpvScripts.autoload}/share/mpv/scripts/autoload.lua";

    # 同步为原生 mpv 准备脚本
    "mpv/scripts/autoload.lua".source = "${pkgs.mpvScripts.autoload}/share/mpv/scripts/autoload.lua";
  };
}
