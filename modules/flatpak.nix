{ config, fcitxCompatEnv, lib, ... }:

let
  lilyaGlass = import ./glass-settings.nix;

  themeEnv = {
    GSK_RENDERER = "ngl";
    GTK_USE_PORTAL = "1";
    GTK2_RC_FILES = "${config.home.homeDirectory}/.gtkrc-2.0";
    XCURSOR_THEME = lilyaGlass.cursorThemeName;
    XCURSOR_SIZE = "48";
  };

in
{
  services.flatpak = {
    enable = true;

    remotes = [
      {
        name = "flathub";
        location = "https://mirrors.ustc.edu.cn/flathub";
      }
    ];

    packages = [
      "com.qq.QQ"
      "org.onlyoffice.desktopeditors"
    ];

    # Strict declarative Flatpak management: apps not listed here are removed.
    uninstallUnmanaged = true;

    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };

    overrides = {
      global = {
        Context.filesystems = [
          "xdg-config/gtk-3.0:ro"
          "xdg-config/gtk-4.0:ro"
          "xdg-data/themes:ro"
          "xdg-data/icons:ro"
        ];
        Environment = themeEnv;
      };

      "com.qq.QQ" = {
        Context.sockets = [
          "wayland"
          "!x11"
          "fallback-x11"
        ];
        Environment = themeEnv // fcitxCompatEnv;
      };
      "org.onlyoffice.desktopeditors".Environment = themeEnv // fcitxCompatEnv;
    };
  };

  home.activation.qqFlatpakWaylandFlags = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rm -f "$HOME/.var/app/com.qq.QQ/config/qq-flags.conf"
  '';
}
