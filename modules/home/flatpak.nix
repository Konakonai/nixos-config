{ config, fcitxCompatEnv, lib, lilyaGlass, pkgs, ... }:

let
  themeEnv = {
    GTK_THEME = "adw-gtk3";
    GTK_USE_PORTAL = "1";
    GTK2_RC_FILES = "${config.home.homeDirectory}/.gtkrc-2.0";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_STYLE_OVERRIDE = "Darkly";
    XCURSOR_THEME = lilyaGlass.cursorThemeName;
    XCURSOR_SIZE = builtins.toString lilyaGlass.cursorSize;
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
  qqLauncher = pkgs.writeShellScriptBin "qq-session" ''
    set -euo pipefail

    qq_config="$HOME/.var/app/com.qq.QQ/config"
    mkdir -p "$qq_config"
    {
      printf '%s\n' \
        "--ozone-platform=wayland" \
        "--enable-wayland-ime" \
        "--wayland-text-input-version=3"
      case "''${XDG_CURRENT_DESKTOP:-}" in
        *niri*|*Niri*)
          printf '%s\n' \
            "--use-gl=swiftshader" \
            "--enable-unsafe-swiftshader"
          ;;
      esac
    } > "$qq_config/qq-flags.conf"

    exec ${pkgs.flatpak}/bin/flatpak run \
      --branch=stable \
      --arch=x86_64 \
      --command=qq \
      com.qq.QQ "$@"
  '';

in
{
  home.packages = [ qqLauncher ];

  # Shadow the Flatpak export so the Niri-only NVIDIA workaround is selected
  # at launch time and cannot leak into Plasma.
  xdg.dataFile."applications/com.qq.QQ.desktop" = {
    # Flatpak creates this path as an export symlink. Replacing that one
    # generated link is intentional so the launcher can select per-session
    # rendering flags.
    force = true;
    text = ''
      [Desktop Entry]
      Name=QQ
      Exec=${lib.getExe qqLauncher} %U
      Terminal=false
      Type=Application
      Icon=com.qq.QQ
      StartupWMClass=QQ
      Categories=Network;InstantMessaging;
      Comment=QQ
      X-Flatpak=com.qq.QQ
    '';
  };

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

  # Keep declarative reconciliation available through the weekly timer and the
  # manual service, but do not make Home Manager activation or login wait for
  # remote Flatpak work.
  home.activation.flatpak-managed-install =
    lib.mkForce (lib.hm.dag.entryAnywhere "");
  systemd.user.services.flatpak-managed-install.Install.WantedBy =
    lib.mkForce [ ];

  home.activation.qqFlatpakWaylandFlags = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    qq_config="$HOME/.var/app/com.qq.QQ/config"
    mkdir -p "$qq_config"
    rm -f "$qq_config/qq-flags.conf"
    # QQ/Electron on niri/NVIDIA Wayland can flash black blocks via the hardware GL buffer path.
    printf '%s\n' \
      "--ozone-platform=wayland" \
      "--enable-wayland-ime" \
      "--wayland-text-input-version=3" \
      > "$qq_config/qq-flags.conf"
  '';
}
