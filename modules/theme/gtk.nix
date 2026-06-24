{ pkgs, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
in
{
  gtk = {
    enable = true;
    theme = {
      package = pkgs.adw-gtk3;
      name = "adw-gtk3";
    };
    iconTheme = {
      name = lilyaGlass.iconThemeName;
      package = pkgs.colloid-icon-theme;
    };
    cursorTheme = {
      name = lilyaGlass.cursorThemeName;
      package = pkgs.nordzy-cursor-theme;
      size = 48;
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
      gtk-theme-name = "adw-gtk3";
      gtk-application-prefer-dark-theme = 0;
    };
  };
}
