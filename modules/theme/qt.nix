{ config, pkgs, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
  kvantumTheme = "rose-pine-dawn-rose";
  patchedKvantumTheme = pkgs.runCommand "rose-pine-dawn-rose-kvantum-readable-selection" {} ''
    theme_dir="$out/share/Kvantum/themes/${kvantumTheme}"
    mkdir -p "$out/share/Kvantum/themes"
    cp -r "${pkgs.rose-pine-kvantum}/share/Kvantum/themes/${kvantumTheme}" "$out/share/Kvantum/themes/"
    chmod -R u+w "$theme_dir"
    for kvconfig in "$theme_dir"/*.kvconfig; do
      substituteInPlace "$kvconfig" \
        --replace-fail "highlight.text.color=#faf4ed" "highlight.text.color=#575279" \
        --replace-fail "link.color=#56949f" "link.color=#b4637a" \
        --replace-fail "link.visited.color=#907aa9" "link.visited.color=#d7827e" \
        --replace-fail "text.press.color=#faf4ed" "text.press.color=#575279" \
        --replace-fail "text.toggle.color=#faf4ed" "text.toggle.color=#575279"
    done
  '';
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
    active_colors=#575279, #f2e9e1, #fffaf3, #f4ede8, #cecacd, #dfdad9, #575279, #575279, #575279, #fffaf3, #faf4ed, #cecacd, #d7827e, #575279, #b4637a, #d7827e, #f2e9e1, #f4ede8, #fffaf3, #575279, #797593, #d7827e
    disabled_colors=#9893a5, #f2e9e1, #fffaf3, #f4ede8, #cecacd, #dfdad9, #9893a5, #9893a5, #9893a5, #fffaf3, #faf4ed, #cecacd, #d7827e, #575279, #9893a5, #9893a5, #f2e9e1, #f4ede8, #fffaf3, #9893a5, #9893a5, #9893a5
    inactive_colors=#575279, #f2e9e1, #fffaf3, #f4ede8, #cecacd, #dfdad9, #575279, #575279, #575279, #fffaf3, #faf4ed, #cecacd, #d7827e, #575279, #b4637a, #d7827e, #f2e9e1, #f4ede8, #fffaf3, #575279, #797593, #d7827e
  '';
  xdg.configFile."Kvantum/${kvantumTheme}".source = "${patchedKvantumTheme}/share/Kvantum/themes/${kvantumTheme}";
  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=${kvantumTheme}
  '';
}
