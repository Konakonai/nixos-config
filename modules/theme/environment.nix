{ config, pkgs, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
in
{
  home.sessionVariables = {
    GSK_RENDERER = "ngl";
    GTK_USE_PORTAL = "1";
    GTK2_RC_FILES = "${config.home.homeDirectory}/.gtkrc-2.0";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_WAYLAND_DECORATION = "adwaita";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    XCURSOR_THEME = lilyaGlass.cursorThemeName;
    XCURSOR_SIZE = "48";
    XCURSOR_PATH = "${pkgs.rose-pine-cursor}/share/icons";
  };
}
