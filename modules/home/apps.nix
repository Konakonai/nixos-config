{ config, pkgs, lib, fcitxCompatEnv, lilyaGlass, ... }:

let
  inherit (pkgs.lilya) antigravity brave-origin brave-netflix-opera cc-switch-cli mindustry splayer;
  localsendNoCsd = pkgs.symlinkJoin {
    name = "${pkgs.localsend.name}-no-csd";
    paths = [ pkgs.localsend ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    # niri does not provide server-side decorations, and LocalSend's Flutter
    # runner otherwise adds a redundant GTK header bar on every Wayland session.
    postBuild = ''
      rm "$out/bin/localsend_app"
      makeWrapper ${lib.getExe pkgs.localsend} "$out/bin/localsend_app" \
        --set GTK_CSD 0
    '';
    meta = pkgs.localsend.meta;
  };
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
    brave-origin
    brave-netflix-opera
    chromium
    file-roller
    foliate
    gnome-font-viewer
    heroic
    hyprpicker
    localsendNoCsd
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

    antigravity
    splayer
    (pkgs.lilya.wechat { inherit fcitxCompatEnv appThemeEnv; })
  ];

  xdg.desktopEntries = {
    "cc-switch-handler" = {
      name = "CC Switch";
      exec = "${lib.getExe cc-switch-cli} %u";
      type = "Application";
      terminal = false;
      noDisplay = true;
      mimeType = [ "x-scheme-handler/ccswitch" ];
    };

    antigravity = {
      name = "Antigravity";
      exec = "${lib.getExe antigravity} %F";
      icon = "antigravity";
      type = "Application";
      categories = [ "Utility" ];
      terminal = false;
      mimeType = [ "x-scheme-handler/antigravity" ];
    };

    mindustry = {
      name = "Mindustry";
      genericName = "Tower Defense Game";
      exec = "${lib.getExe mindustry} %U";
      icon = "mindustry";
      type = "Application";
      terminal = false;
      categories = [ "Game" "StrategyGame" ];
      startupNotify = true;
    };
  };
}
