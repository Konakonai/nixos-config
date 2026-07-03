{ config, pkgs, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
  orchisKde = pkgs.callPackage ../../pkgs/orchis-kde/default.nix {};
  kvantumTheme = "Orchis";
  qtFont = "${lilyaGlass.fonts.sans},${builtins.toString lilyaGlass.fonts.size},-1,5,50,0,0,0,0,0";
  qtFixedFont = "${lilyaGlass.fonts.mono},${builtins.toString lilyaGlass.fonts.size},-1,5,50,0,0,0,0,0";
  qtFontQss = "lilya-fonts.qss";
  qtctConfig = qtctDir: ''
    [Appearance]
    color_scheme_path=${config.home.homeDirectory}/.config/${qtctDir}/colors/noctalia.conf
    custom_palette=false
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
    stylesheets=${config.home.homeDirectory}/.config/${qtctDir}/qss/${qtFontQss}
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
  ];

  qt = {
    enable = true;
    platformTheme.name = "qt6ct";
  };

  xdg.configFile."qt6ct/qt6ct.conf".text = qtctConfig "qt6ct";
  xdg.configFile."qt6ct/qss/${qtFontQss}".text = ''
    QWidget {
      font-family: "${lilyaGlass.fonts.sans}";
      font-size: ${builtins.toString lilyaGlass.fonts.size}pt;
      font-weight: normal;
    }

    QGroupBox::title {
      font-weight: 500;
    }
  '';
  xdg.configFile."Kvantum/${kvantumTheme}".source = "${orchisKde}/share/Kvantum/${kvantumTheme}";
  xdg.configFile."Kvantum/Orchis-solid".source = "${orchisKde}/share/Kvantum/Orchis-solid";
  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=${kvantumTheme}
  '';
  xdg.dataFile."color-schemes/Orchis.colors".source = "${orchisKde}/share/color-schemes/Orchis.colors";
  xdg.dataFile."color-schemes/OrchisDark.colors".source = "${orchisKde}/share/color-schemes/OrchisDark.colors";
}
