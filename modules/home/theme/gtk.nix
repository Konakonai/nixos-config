{ config, lib, lilyaGlass, pkgs, ... }:

let
  gtkThemeName = "Plasma-Overdose-GTK";
  gtkThemePackage = pkgs.lilya.plasma-overdose-gtk-theme;
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
  # Load the same GTK3/GTK4 theme as user CSS so Foliate, Mission Center, and
  # other CSD applications retain the Windows 95 widget geometry. Noctalia's
  # later color imports stay authoritative for the active palette.
  home.activation.installGtkOverdoseOverlay = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    install_overlay() {
      local version="$1"
      local config_dir=${lib.escapeShellArg config.xdg.configHome}/"gtk-$version"
      local overlay_dir="$config_dir/plasma-overdose"
      local gtk_css="$config_dir/gtk.css"
      local import_line='@import url("plasma-overdose/gtk.css");'
      local temp_file

      mkdir -p "$config_dir"
      if [ -e "$overlay_dir" ]; then
        chmod -R u+w "$overlay_dir" 2>/dev/null || true
        rm -rf "$overlay_dir"
      fi
      mkdir -p "$overlay_dir"
      cp -aL ${gtkThemePackage}/share/themes/${gtkThemeName}/"gtk-$version"/. "$overlay_dir/"
      chmod -R u+w "$overlay_dir"

      touch "$gtk_css"
      if ! ${pkgs.gnugrep}/bin/grep -Fqx "$import_line" "$gtk_css"; then
        temp_file="$(${pkgs.coreutils}/bin/mktemp "$config_dir/gtk.css.XXXXXX")"
        {
          printf '%s\n' "$import_line"
          cat "$gtk_css"
        } > "$temp_file"
        mv "$temp_file" "$gtk_css"
      fi
    }

    install_overlay 3.0
    install_overlay 4.0
  '';
}
