{ config, lilyaGlass, pkgs, ... }:

{
  home.sessionVariables = {
    GSK_RENDERER = "ngl";
    GTK_USE_PORTAL = "1";
    GTK2_RC_FILES = "${config.home.homeDirectory}/.gtkrc-2.0";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_WAYLAND_DECORATION = "adwaita";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    CC_SWITCH_TUI_THEME = "${config.home.homeDirectory}/.config/cc-switch/theme/noctalia.json";
    XCURSOR_THEME = lilyaGlass.cursorThemeName;
    XCURSOR_SIZE = builtins.toString lilyaGlass.cursorSize;
    XCURSOR_PATH = "${pkgs.lilya.plasma-overdose-cursors}/share/icons";
  };
}
