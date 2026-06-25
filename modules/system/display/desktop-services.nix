{ pkgs, ... }:

{
  services.xserver = {
    enable = true;
    excludePackages = [ pkgs.xterm ];
    xkb = {
      layout = "us";
      variant = "";
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
    pkgs.ntfs3g
    pkgs.wsdd
  ];

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      var localStorageActions = [
        "org.freedesktop.udisks2.filesystem-mount",
        "org.freedesktop.udisks2.filesystem-mount-system",
        "org.freedesktop.udisks2.filesystem-unmount-others"
      ];

      if (subject.isInGroup("wheel") && localStorageActions.indexOf(action.id) >= 0) {
        return polkit.Result.YES;
      }
    });
  '';

  security.sudo.extraConfig = "Defaults pwfeedback";

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config = {
      common = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
      niri = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
    };
  };

  programs.appimage = {
    enable = true;
    binfmt = true;
  };
}
