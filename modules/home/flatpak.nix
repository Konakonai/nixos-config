{
  config,
  lib,
  lilyaTheme,
  pkgs,
  ...
}:

let
  themeEnv = {
    GTK_THEME = lilyaTheme.theme.gtk;
    GTK_USE_PORTAL = "1";
    GTK2_RC_FILES = "${config.home.homeDirectory}/.gtkrc-2.0";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_STYLE_OVERRIDE = lilyaTheme.theme.qtStyle;
    XCURSOR_THEME = lilyaTheme.cursorThemeName;
    XCURSOR_SIZE = builtins.toString lilyaTheme.cursorSize;
    XCURSOR_PATH = "${config.home.homeDirectory}/.local/share/icons";
  };

  # Sandboxed toolkits do not see the host session's input-method variables.
  imEnv = {
    XMODIFIERS = "@im=fcitx";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "fcitx";
  };

  # Theme directories under ~/.local/share are symlinks into the store, so the
  # sandbox also needs the store itself (read-only; it is world-readable anyway).
  themeFilesystems = [
    "/nix/store:ro"
    "xdg-config/gtk-3.0:ro"
    "xdg-config/gtk-4.0:ro"
    "xdg-config/qt6ct:ro"
    "xdg-data/themes:ro"
    "xdg-data/icons:ro"
  ];

  # Keep Electron apps on Wayland while retaining the real X11 socket for
  # compatibility. Flatpak 1.18 crashes on the leading empty permission entry
  # nix-flatpak writes for a negated socket such as !fallback-x11.
  electronOverride = {
    Context.sockets = [
      "wayland"
      "x11"
    ];
    Context.filesystems = themeFilesystems;
    Environment =
      themeEnv
      // imEnv
      // {
        ELECTRON_OZONE_PLATFORM_HINT = "wayland";
        NIXOS_OZONE_WL = "1";
      };
  };

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

  # Expose the GTK and icon themes to Flatpak applications. home.pointerCursor
  # already links the cursor theme into ~/.local/share/icons.
  xdg.dataFile = {
    "themes/${lilyaTheme.theme.gtk}".source = "${pkgs.adw-gtk3}/share/themes/${lilyaTheme.theme.gtk}";
    "icons/${lilyaTheme.iconThemeName}".source =
      "${pkgs.colloid-icon-theme}/share/icons/${lilyaTheme.iconThemeName}";
    "icons/Adwaita".source = "${pkgs.adwaita-icon-theme}/share/icons/Adwaita";
  };

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
      "com.getpostman.Postman"
      "com.tencent.WeChat"
      "io.github.kukuruzka165.materialgram"
    ];

    # Keep manually installed Flatpak applications alongside the declared set.
    uninstallUnmanaged = false;

    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };

    overrides = {
      "com.qq.QQ" = electronOverride;
      "com.getpostman.Postman" = electronOverride;
      "io.github.kukuruzka165.materialgram" = {
        # Upstream only grants home:ro, so writes to the default
        # ~/Downloads/Telegram Desktop location fail inside the sandbox.
        Context.filesystems = themeFilesystems ++ [ "xdg-download" ];
        # Cursor only: the GNOME runtime ships no qt6ct plugin, so the full
        # themeEnv would point Qt at a missing platform theme.
        Environment = {
          inherit (themeEnv) XCURSOR_THEME XCURSOR_SIZE XCURSOR_PATH;
        };
      };
      "com.tencent.WeChat" = {
        Context.sockets = [
          "wayland"
          "x11"
        ];
        # WeChat's Qt file dialog runs inside the sandbox instead of the
        # portal, so "Save As" and file sending only reach folders listed
        # here; Flathub grants Desktop/Documents/Pictures but not Videos or
        # Downloads.
        Context.filesystems = themeFilesystems ++ [
          "xdg-videos"
          "xdg-download"
        ];
        # Stay on X11: Flathub enabled native Wayland for 4.1.13.9 and
        # reverted it the same day. Do not set QT_ENABLE_HIGHDPI_SCALING or
        # QT_SCALE_FACTOR_ROUNDING_POLICY=PassThrough on this xcb path;
        # those double-scale under niri 1.5 and offset the UI. The bundled
        # Qt5 fcitx plugin still needs X11 to avoid candidate drift.
        Environment =
          themeEnv
          // imEnv
          // {
            QT_QPA_PLATFORM = "xcb";
            QT_AUTO_SCREEN_SCALE_FACTOR = "1";
          };
      };
    };
  };

  # Keep declarative reconciliation available through the weekly timer and the
  # manual service, but do not make Home Manager activation or login wait for
  # remote Flatpak work.
  home.activation.flatpak-managed-install = lib.mkForce (lib.hm.dag.entryAnywhere "");
  systemd.user.services.flatpak-managed-install.Install.WantedBy = lib.mkForce [ ];
  systemd.user.services.flatpak-managed-install.Unit.ConditionACPower = true;
  systemd.user.services.flatpak-managed-install-timer.Unit.ConditionACPower = true;
}
