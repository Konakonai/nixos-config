{ config, fcitxCompatEnv, ... }:

let
  lilyaGlass = import ./glass-settings.nix;

  themeEnv = {
    GSK_RENDERER = "ngl";
    GTK_THEME = "rose-pine-dawn";
    GTK_USE_PORTAL = "1";
    GTK2_RC_FILES = "${config.home.homeDirectory}/.gtkrc-2.0";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_STYLE_OVERRIDE = "kvantum";
    XCURSOR_THEME = lilyaGlass.cursorThemeName;
    XCURSOR_SIZE = "48";
    XCURSOR_PATH = "${config.home.homeDirectory}/.local/share/icons";
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
      "com.qq.QQ".Environment = fcitxCompatEnv;

      "org.onlyoffice.desktopeditors" = {
        Context.filesystems = [
          "xdg-config/gtk-3.0:ro"
          "xdg-config/gtk-4.0:ro"
          "xdg-config/Kvantum:ro"
          "xdg-config/qt6ct:ro"
          "xdg-data/themes:ro"
          "xdg-data/icons:ro"
        ];
        Environment = themeEnv // fcitxCompatEnv;
      };
    };
  };
}
