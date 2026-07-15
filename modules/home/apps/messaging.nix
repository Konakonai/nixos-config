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
in
{
  home.packages = [
    (pkgs.lilya.wechat { inherit fcitxCompatEnv appThemeEnv; })
    pkgs.ayugram-desktop
  ];

  # AyuGram otherwise rounds niri's 1.5x/1.75x output scales before painting.
  # Merge only this display invariant and leave other experimental settings
  # writable and owned by the application.
  home.activation.enableAyuGramFractionalScaling =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      options="$HOME/.local/share/AyuGramDesktop/tdata/experimental_options.json"
      ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$options")"

      if [ ! -e "$options" ]; then
        ${pkgs.coreutils}/bin/printf '%s\n' \
          '{"fractional-scaling-enabled":true}' > "$options"
      elif ${lib.getExe pkgs.jq} -e 'type == "object"' "$options" >/dev/null 2>&1; then
        if ! ${lib.getExe pkgs.jq} -e '."fractional-scaling-enabled" == true' "$options" >/dev/null; then
          temporary="$(${pkgs.coreutils}/bin/mktemp "$options.XXXXXX")"
          ${lib.getExe pkgs.jq} '."fractional-scaling-enabled" = true' "$options" > "$temporary"
          ${pkgs.coreutils}/bin/chmod --reference="$options" "$temporary"
          ${pkgs.coreutils}/bin/mv "$temporary" "$options"
        fi
      else
        echo "warning: leaving invalid AyuGram experimental options unchanged: $options" >&2
      fi
    '';
}
