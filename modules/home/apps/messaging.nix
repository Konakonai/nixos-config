{ config, fcitxCompatEnv, lilyaTheme, pkgs, ... }:

let
  appThemeEnv = {
    GTK_THEME = lilyaTheme.theme.gtk;
    GTK_USE_PORTAL = "1";
    GTK2_RC_FILES = "${config.home.homeDirectory}/.gtkrc-2.0";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_STYLE_OVERRIDE = lilyaTheme.theme.qtStyle;
    XCURSOR_THEME = lilyaTheme.cursorThemeName;
    XCURSOR_SIZE = builtins.toString lilyaTheme.cursorSize;
    XCURSOR_PATH = "${pkgs.catppuccin-cursors.frappeLavender}/share/icons:${pkgs.adwaita-icon-theme}/share/icons";
  };
in
{
  home.packages = [
    (pkgs.lilya.wechat { inherit fcitxCompatEnv appThemeEnv; })
  ];
}
