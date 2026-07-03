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
  fallbackQtColors = ''
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

  home.activation.darklyNoctaliaKdeColors = lib.hm.dag.entryAfter [ "onFilesChange" ] ''
    source="$HOME/.config/qt6ct/colors/noctalia.conf"
    target="$HOME/.config/qt6ct/colors/${qtColorSchemeName}"
    mkdir -p "$(dirname "$target")"

    if [ -f "$source" ]; then
      tmp="$target.tmp"
      ${pkgs.gawk}/bin/awk '
        /^(active_colors|disabled_colors|inactive_colors)=/ {
          split($0, kv, "=")
          key = kv[1]
          value = substr($0, length(key) + 2)
          n = split(value, colors, ",")
          for (i = 1; i <= n; i++) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", colors[i])
          }
          colors[14] = colors[1]
          line = colors[1]
          for (i = 2; i <= n; i++) {
            line = line ", " colors[i]
          }
          print key "=" line
          next
        }
        { print }
      ' "$source" > "$tmp"
      mv "$tmp" "$target"
    else
      cat > "$target" <<'EOF'
${fallbackQtColors}
EOF
    fi

    role_color() {
      local role="$1"
      ${pkgs.gawk}/bin/awk -F= -v role="$role" '
        /^active_colors=/ {
          split($2, colors, ",")
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", colors[role])
          print colors[role]
          exit
        }
      ' "$target"
    }

    hex_to_rgb() {
      local hex="''${1#\#}"
      if [ "''${#hex}" -ne 6 ]; then
        printf '229,205,204'
        return
      fi
      printf '%d,%d,%d' "0x''${hex:0:2}" "0x''${hex:2:2}" "0x''${hex:4:2}"
    }

    selection_bg="$(hex_to_rgb "$(role_color 13)")"
    selection_fg="$(hex_to_rgb "$(role_color 14)")"

    kdeglobals="$HOME/.config/kdeglobals"
    if [ -f "$kdeglobals" ]; then
      ${lib.getExe' pkgs.kdePackages.kconfig "kwriteconfig6"} --file "$kdeglobals" --group "Colors:View" --key "DecorationFocus" "$selection_bg"
      ${lib.getExe' pkgs.kdePackages.kconfig "kwriteconfig6"} --file "$kdeglobals" --group "Colors:View" --key "DecorationHover" "$selection_bg"
      ${lib.getExe' pkgs.kdePackages.kconfig "kwriteconfig6"} --file "$kdeglobals" --group "Colors:Selection" --key "BackgroundAlternate" "$selection_bg"
      ${lib.getExe' pkgs.kdePackages.kconfig "kwriteconfig6"} --file "$kdeglobals" --group "Colors:Selection" --key "BackgroundNormal" "$selection_bg"
      ${lib.getExe' pkgs.kdePackages.kconfig "kwriteconfig6"} --file "$kdeglobals" --group "Colors:Selection" --key "ForegroundActive" "$selection_fg"
      ${lib.getExe' pkgs.kdePackages.kconfig "kwriteconfig6"} --file "$kdeglobals" --group "Colors:Selection" --key "ForegroundNormal" "$selection_fg"
    fi
  '';
}
