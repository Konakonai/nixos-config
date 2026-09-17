{ config, lib, lilyaTheme, pkgs, ... }:

let
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
    categories = [ "Settings" "DesktopSettings" "Qt" ];
    terminal = false;
    noDisplay = true;
  };
}
