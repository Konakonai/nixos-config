{ config, pkgs, lib, fcitxCompatEnv, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
  braveOrigin = import ../../pkgs/brave-origin.nix { inherit pkgs lib; };
  braveNetflixOpera = import ../../pkgs/brave-netflix-opera.nix { inherit pkgs lib braveOrigin; };
  mindustry = import ../../pkgs/mindustry.nix { inherit pkgs lib; };
  appThemeEnv = {
    GTK_THEME = "adw-gtk3";
    GTK_USE_PORTAL = "1";
    GTK2_RC_FILES = "${config.home.homeDirectory}/.gtkrc-2.0";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_STYLE_OVERRIDE = "Darkly";
    XCURSOR_THEME = lilyaGlass.cursorThemeName;
    XCURSOR_SIZE = "48";
    XCURSOR_PATH = "${pkgs.rose-pine-cursor}/share/icons";
  };
in
{
  home.packages = with pkgs; [
    cabextract
    braveOrigin
    braveNetflixOpera
    chromium
    file-roller
    foliate
    gnome-font-viewer
    heroic
    hyprpicker
    localsend
    loupe
    mindustry
    gamescope
    mangohud
    mission-center
    nemo-with-extensions
    pavucontrol
    pwvucontrol
    crosspipe
    protonup-qt
    resources
    wineWow64Packages.stableFull
    winetricks
    obsidian

    (import ../../pkgs/antigravity.nix { inherit pkgs lib; })
    (import ../../pkgs/splayer.nix { inherit pkgs lib; })
    (import ../../pkgs/wechat.nix { inherit pkgs lib fcitxCompatEnv appThemeEnv; })
  ];
}
