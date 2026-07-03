{ config, pkgs, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
  kvantumTheme = "rose-pine-dawn-foam";
  qtFont = "${lilyaGlass.fonts.sans},${builtins.toString lilyaGlass.fonts.size},-1,5,50,0,0,0,0,0";
  qtFixedFont = "${lilyaGlass.fonts.mono},${builtins.toString lilyaGlass.fonts.size},-1,5,50,0,0,0,0,0";
  qtctConfig = qtctDir: ''
    [Appearance]
    color_scheme_path=${config.home.homeDirectory}/.config/${qtctDir}/colors/rose-pine-dawn.conf
    custom_palette=true
    icon_theme=${lilyaGlass.iconThemeName}
    standard_dialogs=default
    style=kvantum

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
  home.packages = [
    pkgs.kdePackages.qtstyleplugin-kvantum
    pkgs.rose-pine-kvantum
  ];

  qt = {
    enable = true;
    platformTheme.name = "qt6ct";
    style.name = "kvantum";
  };

  xdg.configFile."qt6ct/qt6ct.conf".text = qtctConfig "qt6ct";
  xdg.configFile."qt6ct/colors/rose-pine-dawn.conf".text = ''
    [ColorScheme]
    active_colors=#575279, #f2e9e1, #fffaf3, #f4ede8, #cecacd, #dfdad9, #575279, #fffaf3, #575279, #fffaf3, #faf4ed, #cecacd, #56949f, #faf4ed, #286983, #907aa9, #f2e9e1, #f4ede8, #fffaf3, #575279, #797593, #56949f
    disabled_colors=#9893a5, #f2e9e1, #fffaf3, #f4ede8, #cecacd, #dfdad9, #9893a5, #fffaf3, #9893a5, #fffaf3, #faf4ed, #cecacd, #d7827e, #faf4ed, #9893a5, #9893a5, #f2e9e1, #f4ede8, #fffaf3, #9893a5, #9893a5, #9893a5
    inactive_colors=#575279, #f2e9e1, #fffaf3, #f4ede8, #cecacd, #dfdad9, #575279, #fffaf3, #575279, #fffaf3, #faf4ed, #cecacd, #56949f, #faf4ed, #286983, #907aa9, #f2e9e1, #f4ede8, #fffaf3, #575279, #797593, #56949f
  '';
  xdg.configFile."Kvantum/${kvantumTheme}".source = "${pkgs.rose-pine-kvantum}/share/Kvantum/themes/${kvantumTheme}";
  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=${kvantumTheme}
  '';
}
