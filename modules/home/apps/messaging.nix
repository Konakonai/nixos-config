{ config, fcitxCompatEnv, lib, lilyaGlass, pkgs, ... }:

let
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

  wemeetFcitx = pkgs.symlinkJoin {
    name = "${pkgs.wemeet.name}-fcitx";
    paths = [ pkgs.wemeet ];
    nativeBuildInputs = [ pkgs.makeWrapper ];

    postBuild = ''
      for program in wemeet wemeet-xwayland; do
        rm "$out/bin/$program"
        makeWrapper "${pkgs.wemeet}/bin/$program" "$out/bin/$program" \
          ${lib.concatStringsSep " " (
            lib.mapAttrsToList (name: value: "--set ${name} ${lib.escapeShellArg value}") fcitxCompatEnv
          )}
      done
    '';

    meta = pkgs.wemeet.meta;
  };
in
{
  home.packages = [
    (pkgs.lilya.wechat { inherit fcitxCompatEnv appThemeEnv; })
    wemeetFcitx
  ];
}
