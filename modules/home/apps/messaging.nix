{ config, fcitxCompatEnv, lilyaGlass, pkgs, ... }:

let
  appThemeEnv = {
    GTK_THEME = "adw-gtk3";
    GTK_USE_PORTAL = "1";
    GTK2_RC_FILES = "${config.home.homeDirectory}/.gtkrc-2.0";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_STYLE_OVERRIDE = "klassy";
    XCURSOR_THEME = lilyaGlass.cursorThemeName;
    XCURSOR_SIZE = builtins.toString lilyaGlass.cursorSize;
    XCURSOR_PATH = "${pkgs.catppuccin-cursors.frappeLavender}/share/icons:${pkgs.adwaita-icon-theme}/share/icons";
  };
in
{
  home.packages = [
    (pkgs.lilya.wechat { inherit fcitxCompatEnv appThemeEnv; })
  ];
}
