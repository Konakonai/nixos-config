{ pkgs, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
  darklyQtTemplate = pkgs.writeText "noctalia-darkly-qtct.conf" ''
    [ColorScheme]
    # windowText,button,light,midlight,dark,mid,text,brightText,buttonText,base,window,shadow,highlight,highlightedText,link,linkVisited,alternateBase,NO_IDEA,toolTipBase,toolTipText,placeholderText,accent
    active_colors={{colors.on_background.default.hex}}, {{colors.surface.default.hex}}, #ffffff, #cacaca, #9f9f9f, #b8b8b8, {{colors.on_background.default.hex}}, #ffffff, {{colors.on_surface.default.hex}}, {{colors.background.default.hex}}, {{colors.background.default.hex}}, {{colors.shadow.default.hex}}, {{colors.primary_container.default.hex}}, {{colors.on_background.default.hex}}, {{colors.secondary.default.hex}}, {{colors.primary.default.hex}}, {{colors.surface_variant.default.hex}}, {{colors.surface.default.hex}}, {{colors.surface_variant.default.hex}}, {{colors.on_surface.default.hex}}, {{colors.on_surface_variant.default.hex}}, {{colors.primary.default.hex}}
    disabled_colors={{colors.on_surface_variant.default.hex}}, {{colors.surface.default.hex}}, #ffffff, #cacaca, #9f9f9f, #b8b8b8, {{colors.on_surface_variant.default.hex}}, #ffffff, {{colors.on_surface_variant.default.hex}}, {{colors.background.default.hex}}, {{colors.background.default.hex}}, {{colors.shadow.default.hex}}, {{colors.primary_container.default.hex}}, {{colors.on_surface_variant.default.hex}}, {{colors.secondary.default.hex}}, {{colors.primary.default.hex}}, {{colors.surface_variant.default.hex}}, {{colors.surface.default.hex}}, {{colors.surface_variant.default.hex}}, {{colors.on_surface_variant.default.hex}}, {{colors.on_surface_variant.default.hex}}, {{colors.primary.default.hex}}
    inactive_colors={{colors.on_background.default.hex}}, {{colors.surface.default.hex}}, #ffffff, #cacaca, #9f9f9f, #b8b8b8, {{colors.on_background.default.hex}}, #ffffff, {{colors.on_surface.default.hex}}, {{colors.background.default.hex}}, {{colors.background.default.hex}}, {{colors.shadow.default.hex}}, {{colors.primary_container.default.hex}}, {{colors.on_background.default.hex}}, {{colors.secondary.default.hex}}, {{colors.primary.default.hex}}, {{colors.surface_variant.default.hex}}, {{colors.surface.default.hex}}, {{colors.surface_variant.default.hex}}, {{colors.on_surface.default.hex}}, {{colors.on_surface_variant.default.hex}}, {{colors.primary.default.hex}}
  '';
  darklyKdeHook = pkgs.writeShellScript "noctalia-darkly-kde-colors" ''
    set -eu

    config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
    data_home="''${XDG_DATA_HOME:-$HOME/.local/share}"
    qt_scheme="$config_home/qt6ct/colors/darkly-noctalia.conf"

    role_color() {
      local role="$1"
      ${pkgs.gawk}/bin/awk -F= -v role="$role" '
        /^active_colors=/ {
          split($2, colors, ",")
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", colors[role])
          print colors[role]
          exit
        }
      ' "$qt_scheme"
    }

    hex_to_rgb() {
      local hex="''${1#\#}"
      if [ "''${#hex}" -ne 6 ]; then
        printf '229,205,204'
        return
      fi
      printf '%d,%d,%d' "0x''${hex:0:2}" "0x''${hex:2:2}" "0x''${hex:4:2}"
    }

    [ -f "$qt_scheme" ] || exit 0

    selection_bg="$(hex_to_rgb "$(role_color 13)")"
    selection_fg="$(hex_to_rgb "$(role_color 14)")"

    patch_colors() {
      local file="$1"
      [ -f "$file" ] || return 0

      ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file "$file" --group "Colors:View" --key "DecorationFocus" "$selection_bg"
      ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file "$file" --group "Colors:View" --key "DecorationHover" "$selection_bg"
      ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file "$file" --group "Colors:Selection" --key "BackgroundAlternate" "$selection_bg"
      ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file "$file" --group "Colors:Selection" --key "BackgroundNormal" "$selection_bg"
      ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file "$file" --group "Colors:Selection" --key "DecorationFocus" "$selection_bg"
      ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file "$file" --group "Colors:Selection" --key "DecorationHover" "$selection_bg"
      ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file "$file" --group "Colors:Selection" --key "ForegroundActive" "$selection_fg"
      ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file "$file" --group "Colors:Selection" --key "ForegroundNormal" "$selection_fg"
    }

    patch_colors "$data_home/color-schemes/noctalia.colors"
    patch_colors "$config_home/kdeglobals"

    ${pkgs.dbus}/bin/dbus-send /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:0 int32:0 >/dev/null 2>&1 || true
  '';
in
{
  programs.noctalia = {
    enable = true;

    settings = {
      shell = {
        corner_radius_scale = 1.65;
        font_family = lilyaGlass.fonts.sans;

        animation = {
          enabled = true;
          speed = 0.92;
        };

        shadow = {
          direction = "down";
          alpha = 0.18;
        };

        panel = {
          transparency_mode = lilyaGlass.noctalia.panelTransparencyMode;
          borders = false;
          shadow = false;
          launcher_placement = "centered";
          clipboard_placement = "centered";
          control_center_placement = "floating";
          wallpaper_placement = "floating";
          session_placement = "floating";
        };
      };

      bar.main = {
        position = "top";
        thickness = 38;
        background_opacity = lilyaGlass.opacity.noctaliaPanels;
        radius = lilyaGlass.radius.panels;
        margin_ends = 180;
        margin_edge = 10;
        padding = 0;
        widget_spacing = 10;
        scale = 1.0;
        shadow = false;
        auto_hide = false;
        reserve_space = true;
        capsule = false;
        capsule_fill = "surface_variant";
        capsule_radius = lilyaGlass.radius.capsules;
        capsule_opacity = lilyaGlass.opacity.noctaliaCapsules;
        capsule_border = "outline";
        start = [ "launcher" "network" "bluetooth" ];
        center = [ "workspaces" ];
        end = [ "tray" "notifications" "clipboard" "volume" "brightness" "battery" "clock" "control-center" "session" ];
      };

      notification = {
        background_opacity = lilyaGlass.opacity.noctaliaPopups;
        offset_x = 18;
        offset_y = 12;
      };

      osd = {
        background_opacity = lilyaGlass.opacity.noctaliaPopups;
        offset_x = 18;
        offset_y = 12;
      };

      theme.templates.user.darkly-qt = {
        enabled = true;
        input_path = "${darklyQtTemplate}";
        output_path = [
          "$XDG_CONFIG_HOME/qt5ct/colors/darkly-noctalia.conf"
          "$XDG_CONFIG_HOME/qt6ct/colors/darkly-noctalia.conf"
        ];
        post_hook = "${darklyKdeHook}";
        index = 1000;
      };
    };
  };
}
