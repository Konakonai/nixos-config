{ config, fcitxCompatEnv, ... }:

let
  lilyaGlass = import ./glass-settings.nix;

  themeEnv = {
    GTK_USE_PORTAL = "1";
    GTK2_RC_FILES = "${config.home.homeDirectory}/.gtkrc-2.0";
    XCURSOR_THEME = lilyaGlass.cursorThemeName;
    XCURSOR_SIZE = "48";
  };

  electronColorEnv = {
    CHROMIUM_FLAGS = "--force-color-profile=srgb";
    ELECTRON_EXTRA_LAUNCH_ARGS = "--force-color-profile=srgb";
    QTWEBENGINE_CHROMIUM_FLAGS = "--force-color-profile=srgb";
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
      "com.tencent.WeChat"
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
        # Keep QQ rendering on Wayland while giving legacy clipboard paths the
        # real XWayland socket instead of the private Xvfb used by its launcher.
        Context.sockets = [
          "wayland"
          "x11"
          "!fallback-x11"
        ];
        Environment = themeEnv // fcitxCompatEnv // {
          ELECTRON_OZONE_PLATFORM_HINT = "wayland";
          NIXOS_OZONE_WL = "1";
        };
      };
      "org.onlyoffice.desktopeditors".Environment = themeEnv // fcitxCompatEnv;
      "com.tencent.WeChat".Environment = themeEnv // fcitxCompatEnv // electronColorEnv;
    };
  };

  home.file.".var/app/com.qq.QQ/config/qq-flags.conf".text = ''
    --ozone-platform=wayland
    --enable-wayland-ime
    --wayland-text-input-version=3
  '';
}
