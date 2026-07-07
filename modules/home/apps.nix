{ config, pkgs, lib, fcitxCompatEnv, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
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
    chromium
    file-roller
    foliate
    gnome-font-viewer
    heroic
    hyprpicker
    localsend
    loupe
    mangohud
    mission-center
    nemo-with-extensions
    pavucontrol
    protonup-qt
    resources
    wineWow64Packages.stable
    winetricks

    (import ../../pkgs/antigravity.nix { inherit pkgs lib; })
    (import ../../pkgs/qoder-cn.nix { inherit pkgs lib; })
    (import ../../pkgs/splayer.nix { inherit pkgs lib; })
    (import ../../pkgs/wechat.nix { inherit pkgs lib fcitxCompatEnv appThemeEnv; })
  ];

  home.activation.removeQoderUserappDesktop = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for desktop in \
      "$HOME/.local/share/applications/qoder-cn.desktop" \
      "$HOME/.local/share/applications/qoder-cn-url-handler.desktop"
    do
      if [ -f "$desktop" ] && ${pkgs.gnugrep}/bin/grep -q '/nix/store/.*qoder-cn-[0-9]' "$desktop"; then
        rm -f "$desktop"
      fi
    done
  '';
}
