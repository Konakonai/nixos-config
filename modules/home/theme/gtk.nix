{ config, lib, lilyaGlass, pkgs, ... }:

let
  gtkThemeName = "catppuccin-frappe-lavender-compact";
  gtkThemePackage = pkgs.catppuccin-gtk.override {
    accents = [ "lavender" ];
    size = "compact";
    variant = "frappe";
  };
  iconThemePackage = pkgs.catppuccin-papirus-folders.override {
    flavor = "frappe";
    accent = "lavender";
  };
in
{
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
      package = iconThemePackage;
    };
    cursorTheme = {
      name = lilyaGlass.cursorThemeName;
      package = pkgs.catppuccin-cursors.frappeLavender;
      size = lilyaGlass.cursorSize;
    };

    gtk2.extraConfig = ''
      gtk-font-name="${lilyaGlass.fonts.sans} ${builtins.toString lilyaGlass.fonts.size}"
    '';

    gtk3.extraConfig = {
      gtk-font-name = "${lilyaGlass.fonts.sans} ${builtins.toString lilyaGlass.fonts.size}";
      gtk-application-prefer-dark-theme = 1;
    };

    gtk4.extraConfig = {
      gtk-font-name = "${lilyaGlass.fonts.sans} ${builtins.toString lilyaGlass.fonts.size}";
      gtk-theme-name = gtkThemeName;
      gtk-application-prefer-dark-theme = 1;
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
