{ lilyaGlass, pkgs, ... }:

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
      package = pkgs.lilya.plasma-overdose-gtk-theme;
      name = "Plasma-Overdose-GTK";
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
      gtk-theme-name = "Plasma-Overdose-GTK";
      gtk-application-prefer-dark-theme = 0;
    };
  };
}
