{ config, lib, lilyaGlass, pkgs, ... }:

let
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

  home.activation.syncKdeIconTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    kdeglobals=${lib.escapeShellArg "${config.xdg.configHome}/kdeglobals"}
    ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg config.xdg.configHome}
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file "$kdeglobals" \
      --group Icons \
      --key Theme \
      ${lib.escapeShellArg lilyaGlass.iconThemeName}

    ${pkgs.dbus}/bin/dbus-send \
      /KGlobalSettings \
      org.kde.KGlobalSettings.notifyChange \
      int32:0 int32:0 >/dev/null 2>&1 || true
  '';
}
