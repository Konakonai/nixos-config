{ config, lib, lilyaGlass, pkgs, ... }:

let
  gtkThemeName = "Plasma-Overdose-GTK";
  gtkThemePackage = pkgs.lilya.plasma-overdose-gtk-theme;
  libadwaitaOverlay = pkgs.writeText "plasma-overdose-libadwaita.css" (
    builtins.readFile ../../../assets/themes/plasma-overdose-libadwaita.css
  );
in
{
  # GTK4 can report the legacy "gnome" icon theme in Plasma even when the
  # desktop preference is Tela. Keep that lookup usable for libadwaita apps
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
      package = pkgs.tela-icon-theme;
    };
    cursorTheme = {
      name = lilyaGlass.cursorThemeName;
      package = pkgs.lilya.plasma-overdose-theme;
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
  home.activation.installGtkOverdoseOverlay = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    update_user_css() {
      local version="$1"
      local config_dir=${lib.escapeShellArg config.xdg.configHome}/"gtk-$version"
      local gtk_css="$config_dir/gtk.css"
      local legacy_import='@import url("plasma-overdose/gtk.css");'
      local overlay_import='@import url("plasma-overdose-libadwaita.css");'
      local temp_file

      mkdir -p "$config_dir"
      if [ -e "$config_dir/plasma-overdose" ]; then
        chmod -R u+w "$config_dir/plasma-overdose" 2>/dev/null || true
        rm -rf "$config_dir/plasma-overdose"
      fi

      touch "$gtk_css"
      temp_file="$(${pkgs.coreutils}/bin/mktemp "$config_dir/gtk.css.XXXXXX")"
      ${pkgs.gnugrep}/bin/grep -Fvx \
        -e "$legacy_import" \
        -e "$overlay_import" \
        "$gtk_css" > "$temp_file" || true

      if [ "$version" = 4.0 ]; then
        ${pkgs.coreutils}/bin/install -m644 ${libadwaitaOverlay} \
          "$config_dir/plasma-overdose-libadwaita.css"
        {
          printf '%s\n' "$overlay_import"
          cat "$temp_file"
        } > "$gtk_css"
        rm -f "$temp_file"
      else
        rm -f "$config_dir/plasma-overdose-libadwaita.css"
        mv "$temp_file" "$gtk_css"
      fi
    }

    update_user_css 3.0
    update_user_css 4.0
  '';
}
