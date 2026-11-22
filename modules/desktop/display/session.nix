{ lilyaTheme, pkgs, ... }:

{
  console = {
    # kmscon owns the final virtual console. Avoid configuring a kernel VT
    # bitmap font during initrd boot; with the current kernel this setfont path
    # fails and can briefly expose a non-fullscreen text console under Plymouth.
    earlySetup = false;
    font = null;
    packages = [ ];
    # kmscon ignores these. They become vt.default_* kernel parameters and
    # theme the kernel console shown before kmscon takes over (early boot,
    # emergency shell).
    colors = [
      "2e3440"
      "bf616a"
      "a3be8c"
      "ebcb8b"
      "81a1c1"
      "b48ead"
      "88c0d0"
      "e5e9f0"
      "4c566a"
      "bf616a"
      "a3be8c"
      "ebcb8b"
      "81a1c1"
      "b48ead"
      "8fbcbb"
      "eceff4"
    ];
  };

  services.kmscon = {
    enable = true;
    useXkbConfig = true;
    config = {
      # Keep virtual consoles on the boot GPU so kmscon cannot hold the
      # discrete NVIDIA GPU awake after switching to a graphical session.
      gpus = "primary";
      hwaccel = true;
      font-name = lilyaTheme.fonts.sans;
      font-size = 16;
      multi-monitor = "largest";
      term = "xterm-256color";
    };
  };

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

  environment.systemPackages = with pkgs; [
    gsettings-desktop-schemas
    glib
    wsdd
    xwayland-satellite
    brightnessctl
    adwaita-icon-theme
    qadwaitadecorations-qt6
    kdePackages.dolphin
    # Dolphin's embedded terminal panel is a KonsolePart plugin. External
    # "Open Terminal" actions still use Kitty via kdeglobals.
    kdePackages.konsole
    kdePackages.kio-fuse
    kdePackages.kservice
    qt6Packages.qt6ct
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
        default = [
          "gnome"
          "gtk"
        ];
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
