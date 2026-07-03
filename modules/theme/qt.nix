{ config, lib, pkgs, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
  qtColorSchemeName = "darkly-noctalia.conf";
  qtFont = "${lilyaGlass.fonts.sans},${builtins.toString lilyaGlass.fonts.size},-1,5,50,0,0,0,0,0";
  qtFixedFont = "${lilyaGlass.fonts.mono},${builtins.toString lilyaGlass.fonts.size},-1,5,50,0,0,0,0,0";
  qtctConfig = qtctDir: ''
    [Appearance]
    color_scheme_path=${config.home.homeDirectory}/.config/${qtctDir}/colors/${qtColorSchemeName}
    custom_palette=true
    icon_theme=${lilyaGlass.iconThemeName}
    standard_dialogs=default
    style=Darkly

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
  qtColors = ''
    [ColorScheme]
    active_colors=${lilyaGlass.palette.text}, #fffaf3, #ffffff, #f8f1ea, #dfdad9, #cecacd, ${lilyaGlass.palette.text}, #fffaf3, ${lilyaGlass.palette.text}, #fffaf3, ${lilyaGlass.palette.base}, ${lilyaGlass.palette.crust}, #e5cdcc, ${lilyaGlass.palette.text}, #56949f, ${lilyaGlass.palette.lavender}, ${lilyaGlass.palette.mantle}, #fffaf3, ${lilyaGlass.palette.mantle}, ${lilyaGlass.palette.text}, ${lilyaGlass.palette.overlay}, ${lilyaGlass.palette.accent}
    disabled_colors=${lilyaGlass.palette.overlay}, #fffaf3, #ffffff, #f8f1ea, ${lilyaGlass.palette.crust}, #cecacd, ${lilyaGlass.palette.overlay}, #fffaf3, ${lilyaGlass.palette.overlay}, #fffaf3, ${lilyaGlass.palette.base}, ${lilyaGlass.palette.crust}, #e5cdcc, ${lilyaGlass.palette.overlay}, #56949f, ${lilyaGlass.palette.lavender}, ${lilyaGlass.palette.mantle}, #fffaf3, ${lilyaGlass.palette.mantle}, ${lilyaGlass.palette.overlay}, ${lilyaGlass.palette.overlay}, ${lilyaGlass.palette.accent}
    inactive_colors=${lilyaGlass.palette.text}, #fffaf3, #ffffff, #f8f1ea, #dfdad9, #cecacd, ${lilyaGlass.palette.text}, #fffaf3, ${lilyaGlass.palette.text}, #fffaf3, ${lilyaGlass.palette.base}, ${lilyaGlass.palette.crust}, #e5cdcc, ${lilyaGlass.palette.text}, #56949f, ${lilyaGlass.palette.lavender}, ${lilyaGlass.palette.mantle}, #fffaf3, ${lilyaGlass.palette.mantle}, ${lilyaGlass.palette.text}, ${lilyaGlass.palette.overlay}, ${lilyaGlass.palette.accent}
  '';
in
{
  qt = {
    enable = true;
    platformTheme.name = "qt6ct";
    style = {
      name = "Darkly";
      package = pkgs.darkly;
    };
  };

  xdg.configFile."qt6ct/qt6ct.conf".text = qtctConfig "qt6ct";
  xdg.configFile."qt6ct/colors/${qtColorSchemeName}".text = qtColors;

  home.activation.darklyNoctaliaKdeColors = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    kdeglobals="$HOME/.config/kdeglobals"
    if [ -f "$kdeglobals" ]; then
      ${lib.getExe' pkgs.kdePackages.kconfig "kwriteconfig6"} --file "$kdeglobals" --group "Colors:View" --key "DecorationFocus" "229,205,204"
      ${lib.getExe' pkgs.kdePackages.kconfig "kwriteconfig6"} --file "$kdeglobals" --group "Colors:View" --key "DecorationHover" "229,205,204"
    fi
  '';
}
