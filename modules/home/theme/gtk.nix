{ config, lib, lilyaTheme, pkgs, ... }:

let
  gtkThemeName = lilyaTheme.theme.gtk;
  gtkThemePackage = pkgs.adw-gtk3;
  iconThemePackage = pkgs.colloid-icon-theme;
in
{
  xdg.dataFile."icons/gnome/index.theme".text = ''
    [Icon Theme]
    Name=GNOME compatibility
    Comment=Compatibility fallback for GTK applications
    Inherits=${lilyaTheme.iconThemeName},Adwaita,hicolor
    Directories=
  '';

  gtk = {
    enable = true;
    theme = {
      package = gtkThemePackage;
      name = gtkThemeName;
    };
    iconTheme = {
      name = lilyaTheme.iconThemeName;
      package = iconThemePackage;
    };
    cursorTheme = {
      name = lilyaTheme.cursorThemeName;
      package = pkgs.catppuccin-cursors.frappeLavender;
      size = lilyaTheme.cursorSize;
    };

    gtk2.extraConfig = ''
      gtk-font-name="${lilyaTheme.fonts.sans} ${builtins.toString lilyaTheme.fonts.size}"
    '';

    gtk3.extraConfig = {
      gtk-font-name = "${lilyaTheme.fonts.sans} ${builtins.toString lilyaTheme.fonts.size}";
      gtk-application-prefer-dark-theme = 0;
    };

    gtk4.extraConfig = {
      gtk-font-name = "${lilyaTheme.fonts.sans} ${builtins.toString lilyaTheme.fonts.size}";
      gtk-theme-name = gtkThemeName;
      gtk-application-prefer-dark-theme = 0;
    };
  };

  home.activation.cleanLegacyGtkOverlays = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for version in 3.0 4.0; do
      config_dir=${lib.escapeShellArg config.xdg.configHome}/"gtk-$version"
      gtk_css="$config_dir/gtk.css"
      if [ -e "$config_dir/plasma-overdose" ]; then
        chmod -R u+w "$config_dir/plasma-overdose" 2>/dev/null || true
        rm -rf "$config_dir/plasma-overdose"
      fi
      rm -f "$config_dir/plasma-overdose-libadwaita.css"

      if [ -f "$gtk_css" ]; then
        temp_file="$(${pkgs.coreutils}/bin/mktemp "$config_dir/gtk.css.XXXXXX")"
        ${pkgs.gnugrep}/bin/grep -Fvx \
          -e '@import url("plasma-overdose/gtk.css");' \
          -e '@import url("plasma-overdose-libadwaita.css");' \
          "$gtk_css" > "$temp_file" || true
        mv "$temp_file" "$gtk_css"
      fi
    done
  '';
}
