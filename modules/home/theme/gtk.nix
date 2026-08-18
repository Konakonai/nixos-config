{ config, lib, lilyaGlass, pkgs, ... }:

let
  gtkThemeName = "adw-gtk3";
  gtkThemePackage = pkgs.adw-gtk3;
in
{
  # GTK4 can report the legacy "gnome" icon theme in Plasma even when the
  # desktop preference is Colloid. Keep that lookup usable for libadwaita apps
  # such as Foliate without duplicating the actual icon assets.
  xdg.dataFile."icons/gnome/index.theme".text = ''
    [Icon Theme]
    Name=GNOME compatibility
    Comment=Compatibility fallback for GTK applications
    Inherits=${lilyaGlass.iconThemeName},Adwaita,hicolor
    Directories=
  '';

  gtk = {
    enable = true;
    theme = {
      package = gtkThemePackage;
      name = gtkThemeName;
    };
    iconTheme = {
      name = lilyaGlass.iconThemeName;
      package = pkgs.colloid-icon-theme;
    };
    cursorTheme = {
      name = lilyaGlass.cursorThemeName;
      package = pkgs.colloid-cursors;
      size = lilyaGlass.cursorSize;
    };

    gtk2.extraConfig = ''
      gtk-font-name="${lilyaGlass.fonts.sans} ${builtins.toString lilyaGlass.fonts.size}"
    '';

    gtk3.extraConfig = {
      gtk-font-name = "${lilyaGlass.fonts.sans} ${builtins.toString lilyaGlass.fonts.size}";
      gtk-application-prefer-dark-theme = 0;
    };

    gtk4.extraConfig = {
      gtk-font-name = "${lilyaGlass.fonts.sans} ${builtins.toString lilyaGlass.fonts.size}";
      gtk-theme-name = gtkThemeName;
      gtk-application-prefer-dark-theme = 0;
    };
  };

  # Libadwaita installs its own style provider after the selected GTK theme.
  # A full GTK theme at user-CSS priority also overrides application layout,
  # so keep GTK3 on the selected theme and give GTK4 a small structural layer.
  # Noctalia remains authoritative for the live palette.
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
