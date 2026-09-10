{ lilyaTheme, pkgs, ... }:

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
}
