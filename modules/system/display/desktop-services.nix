{ pkgs, ... }:

{
  services.xserver = {
    enable = true;
    excludePackages = [ pkgs.xterm ];
    xkb = {
      layout = "us";
      variant = "";
      options = "caps:super";
    };
  };

  services.accounts-daemon.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.flatpak.enable = true;
  services.samba-wsdd.enable = true;
  services.gnome.at-spi2-core.enable = true;
  programs.dconf.enable = true;

  environment.systemPackages = [
    pkgs.gsettings-desktop-schemas
    pkgs.glib
    pkgs.wsdd
  ];

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      var localStorageActions = [
        "org.freedesktop.udisks2.filesystem-mount",
        "org.freedesktop.udisks2.filesystem-mount-system",
        "org.freedesktop.udisks2.filesystem-unmount-others"
      ];

      if (subject.local && subject.active && subject.isInGroup("wheel") && localStorageActions.indexOf(action.id) >= 0) {
        return polkit.Result.YES;
      }
    });
  '';

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.kdePackages.xdg-desktop-portal-kde
    ];
    config = {
      common = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
      niri = {
        default = [ "gnome" "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
      kde = {
        default = [ "kde" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
        # KDE's portal does not expose org.gnome.desktop.interface settings.
        # GTK 4.22 interprets the missing text scaling factor as zero, which
        # gives WebKitGTK an invalid viewport and blanks Foliate's reader.
        "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
      };
    };
  };

  programs.appimage = {
    enable = true;
    binfmt = true;
  };
}
