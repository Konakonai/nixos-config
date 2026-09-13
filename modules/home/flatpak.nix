{ config, fcitxCompatEnv, lib, lilyaTheme, pkgs, ... }:

let
  themeEnv = {
    GTK_THEME = lilyaTheme.theme.gtk;
    GTK_USE_PORTAL = "1";
    GTK2_RC_FILES = "${config.home.homeDirectory}/.gtkrc-2.0";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_STYLE_OVERRIDE = lilyaTheme.theme.qtStyle;
    XCURSOR_THEME = lilyaTheme.cursorThemeName;
    XCURSOR_SIZE = builtins.toString lilyaTheme.cursorSize;
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

  wechatLauncher = pkgs.writeShellScriptBin "wechat-session" ''
    set -euo pipefail

    export QT_IM_MODULE=fcitx
    export XMODIFIERS=@im=fcitx
    export GTK_IM_MODULE=fcitx
    export QT_QPA_PLATFORM=xcb
    export QT_AUTO_SCREEN_SCALE_FACTOR=1

    exec ${pkgs.flatpak}/bin/flatpak run \
      --branch=stable \
      --arch=x86_64 \
      --command=wechat \
      --env=QT_IM_MODULE=fcitx \
      --env=XMODIFIERS=@im=fcitx \
      --env=GTK_IM_MODULE=fcitx \
      --env=QT_QPA_PLATFORM=xcb \
      --env=QT_AUTO_SCREEN_SCALE_FACTOR=1 \
      --file-forwarding \
      com.tencent.WeChat @@u "$@" @@
  '';

  sanitizeFlatpakOverrides = pkgs.writeShellScript "sanitize-flatpak-overrides" ''
    exec ${pkgs.python3}/bin/python3 ${../../scripts/sanitize-flatpak-overrides.py} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/.local/share/flatpak/overrides"}
  '';

in
{
  home.packages = [ qqLauncher wechatLauncher ];

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

  xdg.dataFile."applications/com.tencent.WeChat.desktop" = {
    force = true;
    text = ''
      [Desktop Entry]
      Name=WeChat
      Name[zh_CN]=微信
      Exec=${lib.getExe wechatLauncher} @@u %U @@
      Terminal=false
      Type=Application
      Icon=com.tencent.WeChat
      StartupWMClass=WeChat
      Categories=Network;InstantMessaging;
      Comment=WeChat Desktop
      Comment[zh_CN]=微信桌面版
      X-Flatpak=com.tencent.WeChat
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
    ];

    # Keep manually installed Flatpak applications alongside the declared set.
    uninstallUnmanaged = false;

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
      "com.getpostman.Postman" = {
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
      "com.tencent.WeChat" = {
        Context.sockets = [
          "wayland"
          "x11"
        ];
        Context.filesystems = themeFilesystems;
        # WeChat's bundled Qt5 embeds a static fcitx platform input context
        # plugin. Direct it to Fcitx via DBus and X11 to eliminate candidate drift.
        Environment = themeEnv // fcitxCompatEnv // {
          QT_QPA_PLATFORM = "xcb";
          QT_AUTO_SCREEN_SCALE_FACTOR = "1";
          XCURSOR_THEME = lilyaTheme.cursorThemeName;
          XCURSOR_SIZE = builtins.toString lilyaTheme.cursorSize;
          XCURSOR_PATH = themeEnv.XCURSOR_PATH;
        };
      };
    };
  };

  # Keep declarative reconciliation available through the weekly timer and the
  # manual service, but do not make Home Manager activation or login wait for
  # remote Flatpak work.
  home.activation.flatpak-managed-install =
    lib.mkForce (lib.hm.dag.entryAnywhere "");
  # nix-flatpak merges leftover override tokens such as a leading empty
  # socket/filesystem entry. Flatpak 1.18 crashes on those empty strings.
  home.activation.sanitizeFlatpakOverrides =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${sanitizeFlatpakOverrides}
    '';
  systemd.user.services.flatpak-managed-install.Install.WantedBy =
    lib.mkForce [ ];
  systemd.user.services.flatpak-managed-install.Unit.ConditionACPower = true;
  systemd.user.services.flatpak-managed-install.Service.ExecStartPost =
    "${sanitizeFlatpakOverrides}";
  systemd.user.services.flatpak-managed-install-timer.Unit.ConditionACPower = true;
}
