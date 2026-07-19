{ config, fcitxCompatEnv, lib, lilyaGlass, ... }:

let
  themeEnv = {
    GSK_RENDERER = "ngl";
    GTK_THEME = "adw-gtk3";
    GTK_USE_PORTAL = "1";
    GTK2_RC_FILES = "${config.home.homeDirectory}/.gtkrc-2.0";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_STYLE_OVERRIDE = "";
    XCURSOR_THEME = lilyaGlass.cursorThemeName;
    XCURSOR_SIZE = "48";
    XCURSOR_PATH = "${config.home.homeDirectory}/.local/share/flatpak-icons:${config.home.homeDirectory}/.local/share/icons";
  };

  themeFilesystems = [
    "xdg-config/gtk-3.0:ro"
    "xdg-config/gtk-4.0:ro"
    "xdg-config/qt6ct:ro"
    "xdg-data/themes:ro"
    "xdg-data/icons:ro"
    "xdg-data/flatpak-icons:ro"
  ];

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
    ];

    # Strict declarative Flatpak management: apps not listed here are removed.
    uninstallUnmanaged = true;

    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };

    overrides = {
      "com.qq.QQ" = {
        # Keep QQ on Wayland while retaining the real X11 socket for compatibility.
        # Flatpak 1.18 crashes on the leading empty permission entry generated
        # when nix-flatpak serializes a negated socket such as !fallback-x11.
        Context.sockets = [
          "wayland"
          "x11"
        ];
        Context.filesystems = themeFilesystems;
        Environment = themeEnv // fcitxCompatEnv // {
          ELECTRON_OZONE_PLATFORM_HINT = "wayland";
          NIXOS_OZONE_WL = "1";
        };
      };
    };
  };

  home.activation.qqFlatpakWaylandFlags = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    qq_config="$HOME/.var/app/com.qq.QQ/config"
    mkdir -p "$qq_config"
    rm -f "$qq_config/qq-flags.conf"
    # QQ/Electron on niri/NVIDIA Wayland can flash black blocks via the hardware GL buffer path.
    printf '%s\n' \
      "--ozone-platform=wayland" \
      "--enable-wayland-ime" \
      "--wayland-text-input-version=3" \
      "--use-gl=swiftshader" \
      "--enable-unsafe-swiftshader" \
      > "$qq_config/qq-flags.conf"
  '';
}
