{ config, fcitxEnv, ... }:

let
  lilyaGlass = import ./glass-settings.nix;

  themeEnv = {
    GTK_THEME = lilyaGlass.gtkThemeName;
    GTK_USE_PORTAL = "1";
    GTK2_RC_FILES = "${config.home.homeDirectory}/.gtkrc-2.0";
    QT_QPA_PLATFORMTHEME = "kvantum";
    QT_STYLE_OVERRIDE = "kvantum";
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
          "xdg-config/Kvantum:ro"
          "xdg-data/themes:ro"
          "xdg-data/icons:ro"
          "xdg-data/Kvantum:ro"
        ];
        Environment = themeEnv;
      };

      "com.qq.QQ".Environment = themeEnv // fcitxEnv;
      "org.onlyoffice.desktopeditors".Environment = themeEnv // fcitxEnv;
      "com.tencent.WeChat".Environment = themeEnv // fcitxEnv // electronColorEnv;
    };
  };
}
