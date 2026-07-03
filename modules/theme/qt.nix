{ config, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
  qtctConfig = qtctDir: ''
    [Appearance]
    color_scheme_path=${config.home.homeDirectory}/.config/${qtctDir}/colors/noctalia.conf
    custom_palette=true
    icon_theme=${lilyaGlass.iconThemeName}
    standard_dialogs=default
    style=Fusion

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
  '';
in
{
  qt = {
    enable = true;
    platformTheme.name = "qt6ct";
  };

  xdg.configFile."qt6ct/qt6ct.conf".text = qtctConfig "qt6ct";
}
