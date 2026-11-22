{
  config,
  lib,
  lilyaTheme,
  pkgs,
  ...
}:

let
  gtkThemeName = lilyaTheme.theme.gtk;
  gtkThemePackage = pkgs.adw-gtk3;
  iconThemePackage = pkgs.colloid-icon-theme;

  qtColorSchemeName = "darkly-noctalia.conf";
  qtFont = "${lilyaTheme.fonts.sans},${builtins.toString lilyaTheme.fonts.size},-1,5,50,0,0,0,0,0";
  qtFixedFont = "${lilyaTheme.fonts.mono},${builtins.toString lilyaTheme.fonts.size},-1,5,50,0,0,0,0,0";
  qtctConfig = qtctDir: ''
    [Appearance]
    color_scheme_path=${config.home.homeDirectory}/.config/${qtctDir}/colors/${qtColorSchemeName}
    custom_palette=true
    icon_theme=${lilyaTheme.iconThemeName}
    standard_dialogs=default
    style=${lilyaTheme.theme.qtStyle}

    [Interface]
    activate_item_on_single_click=1
    buttonbox_layout=0
    cursor_flash_time=1000
    dialog_buttons_have_icons=1
    double_click_interval=400
    keyboard_scheme=2
    menus_have_icons=true
    show_shortcuts_in_context_menus=true
    toolbutton_style=4
    underline_shortcut=1
    wheel_scroll_lines=3

    [Fonts]
    fixed=${qtFixedFont}
    general=${qtFont}
  '';
in
{
  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.catppuccin-cursors.frappeLavender;
    name = lilyaTheme.cursorThemeName;
    size = lilyaTheme.cursorSize;
  };

  # Desktop-independent variables only; home.pointerCursor sets XCURSOR_THEME
  # and XCURSOR_SIZE. The Qt platform theme and decoration choices belong to
  # the niri session (modules/desktop/niri/default.nix); Plasma supplies its own.
  home.sessionVariables = {
    GTK_USE_PORTAL = "1";
    GTK2_RC_FILES = "${config.home.homeDirectory}/.gtkrc-2.0";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    XCURSOR_PATH = "${pkgs.catppuccin-cursors.frappeLavender}/share/icons:${pkgs.adwaita-icon-theme}/share/icons";
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-light";
      cursor-size = lilyaTheme.cursorSize;
      cursor-theme = lilyaTheme.cursorThemeName;
      font-name = "${lilyaTheme.fonts.sans} ${builtins.toString lilyaTheme.fonts.size}";
      gtk-theme = lilyaTheme.theme.gtk;
      icon-theme = lilyaTheme.iconThemeName;
      monospace-font-name = "${lilyaTheme.fonts.mono} ${builtins.toString lilyaTheme.fonts.size}";
      toolkit-accessibility = true;
    };

    "org/gnome/desktop/sound".theme-name = lilyaTheme.theme.sound;
    "org/gnome/desktop/wm/preferences".button-layout = ":minimize,maximize,close";
  };

  xresources.properties = {
    "Xft.dpi" = 144;
    "Xft.autohint" = 0;
    "Xft.lcdfilter" = "lcddefault";
    "Xft.hintstyle" = "hintfull";
    "Xft.hinting" = 1;
    "Xft.antialias" = 1;
    "Xft.rgba" = "rgb";
  };

  xdg.dataFile."icons/gnome/index.theme".text = ''
    [Icon Theme]
    Name=GNOME compatibility
    Comment=Compatibility fallback for GTK applications
    Inherits=${lilyaTheme.iconThemeName},Adwaita,hicolor
    Directories=
  '';

  gtk = {
    enable = true;
    theme = {
      package = gtkThemePackage;
      name = gtkThemeName;
    };
    iconTheme = {
      name = lilyaTheme.iconThemeName;
      package = iconThemePackage;
    };
    cursorTheme = {
      name = lilyaTheme.cursorThemeName;
      package = pkgs.catppuccin-cursors.frappeLavender;
      size = lilyaTheme.cursorSize;
    };

    gtk2.extraConfig = ''
      gtk-font-name="${lilyaTheme.fonts.sans} ${builtins.toString lilyaTheme.fonts.size}"
    '';

    gtk3.extraConfig = {
      gtk-font-name = "${lilyaTheme.fonts.sans} ${builtins.toString lilyaTheme.fonts.size}";
      gtk-application-prefer-dark-theme = 0;
    };

    gtk4.extraConfig = {
      gtk-font-name = "${lilyaTheme.fonts.sans} ${builtins.toString lilyaTheme.fonts.size}";
      gtk-theme-name = gtkThemeName;
      gtk-application-prefer-dark-theme = 0;
    };
  };

  # QT_QPA_PLATFORMTHEME=qt6ct is set only inside the niri session; the qt6ct
  # platform-theme plugin itself comes from the system package set.
  home.packages = [
    pkgs.klassy
  ];

  xdg.configFile."qt6ct/qt6ct.conf".text = qtctConfig "qt6ct";

  xdg.desktopEntries.qt6ct = {
    name = "Qt6 Settings";
    exec = lib.getExe pkgs.qt6Packages.qt6ct;
    icon = "preferences-desktop-theme";
    type = "Application";
    categories = [
      "Settings"
      "DesktopSettings"
      "Qt"
    ];
    terminal = false;
    noDisplay = true;
  };
}
