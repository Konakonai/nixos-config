{ config, pkgs, lib, fcitxCompatEnv, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
  appThemeEnv = {
    GTK_THEME = "rose-pine-dawn";
    GTK_USE_PORTAL = "1";
    GTK2_RC_FILES = "${config.home.homeDirectory}/.gtkrc-2.0";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_STYLE_OVERRIDE = "kvantum";
    XCURSOR_THEME = lilyaGlass.cursorThemeName;
    XCURSOR_SIZE = "48";
    XCURSOR_PATH = "${pkgs.rose-pine-cursor}/share/icons";
  };
in
{
  home.packages = with pkgs; [
    chromium
    file-roller
    gnome-font-viewer
    nemo-with-extensions
    pavucontrol
    mission-center
    resources
    foliate
    localsend
    hyprpicker
    loupe

    (import ../../pkgs/antigravity.nix { inherit pkgs lib; })
    (import ../../pkgs/qoder-cn.nix { inherit pkgs lib; })
    (import ../../pkgs/splayer.nix { inherit pkgs lib; })
    (import ../../pkgs/wechat.nix { inherit pkgs lib fcitxCompatEnv appThemeEnv; })
  ];
}
