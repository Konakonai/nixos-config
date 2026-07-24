{ config, fcitxCompatEnv, lilyaGlass, pkgs, ... }:

let
  appThemeEnv = {
    GTK_THEME = "Plasma-Overdose-GTK";
    GTK_USE_PORTAL = "1";
    GTK2_RC_FILES = "${config.home.homeDirectory}/.gtkrc-2.0";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_STYLE_OVERRIDE = "Windows";
    XCURSOR_THEME = lilyaGlass.cursorThemeName;
    XCURSOR_SIZE = builtins.toString lilyaGlass.cursorSize;
    XCURSOR_PATH = "${pkgs.lilya.plasma-overdose-theme}/share/icons";
  };
in
{
  home.packages = [
    (pkgs.lilya.wechat { inherit fcitxCompatEnv appThemeEnv; })
  ];
}
