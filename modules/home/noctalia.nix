{ config, hostProfile, lib, lilyaGlass, pkgs, ... }:

let
  darklyQtTemplate = pkgs.writeText "noctalia-darkly-qtct.conf" ''
    [ColorScheme]
    # windowText,button,light,midlight,dark,mid,text,brightText,buttonText,base,window,shadow,highlight,highlightedText,link,linkVisited,alternateBase,NO_IDEA,toolTipBase,toolTipText,placeholderText,accent
    active_colors={{colors.on_background.default.hex}}, {{colors.surface.default.hex}}, #ffffff, #cacaca, #9f9f9f, #b8b8b8, {{colors.on_background.default.hex}}, #ffffff, {{colors.on_surface.default.hex}}, {{colors.background.default.hex}}, {{colors.background.default.hex}}, {{colors.shadow.default.hex}}, {{colors.primary_container.default.hex}}, {{colors.on_background.default.hex}}, {{colors.secondary.default.hex}}, {{colors.primary.default.hex}}, {{colors.surface_variant.default.hex}}, {{colors.surface.default.hex}}, {{colors.surface_variant.default.hex}}, {{colors.on_surface.default.hex}}, {{colors.on_surface_variant.default.hex}}, {{colors.primary.default.hex}}
    disabled_colors={{colors.on_surface_variant.default.hex}}, {{colors.surface.default.hex}}, #ffffff, #cacaca, #9f9f9f, #b8b8b8, {{colors.on_surface_variant.default.hex}}, #ffffff, {{colors.on_surface_variant.default.hex}}, {{colors.background.default.hex}}, {{colors.background.default.hex}}, {{colors.shadow.default.hex}}, {{colors.primary_container.default.hex}}, {{colors.on_surface_variant.default.hex}}, {{colors.secondary.default.hex}}, {{colors.primary.default.hex}}, {{colors.surface_variant.default.hex}}, {{colors.surface.default.hex}}, {{colors.surface_variant.default.hex}}, {{colors.on_surface_variant.default.hex}}, {{colors.on_surface_variant.default.hex}}, {{colors.primary.default.hex}}
    inactive_colors={{colors.on_background.default.hex}}, {{colors.surface.default.hex}}, #ffffff, #cacaca, #9f9f9f, #b8b8b8, {{colors.on_background.default.hex}}, #ffffff, {{colors.on_surface.default.hex}}, {{colors.background.default.hex}}, {{colors.background.default.hex}}, {{colors.shadow.default.hex}}, {{colors.primary_container.default.hex}}, {{colors.on_background.default.hex}}, {{colors.secondary.default.hex}}, {{colors.primary.default.hex}}, {{colors.surface_variant.default.hex}}, {{colors.surface.default.hex}}, {{colors.surface_variant.default.hex}}, {{colors.on_surface.default.hex}}, {{colors.on_surface_variant.default.hex}}, {{colors.primary.default.hex}}
  '';
  # Keep this path stable because Noctalia's seed-once config refers to it.
  # The hook only updates Noctalia's standalone color scheme; Plasma owns
  # kdeglobals so changes made in System Settings survive future activations.
  darklyColorSchemeHook = pkgs.writeShellScript "noctalia-darkly-kde-colors" ''
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
  '';

  heroicNoctaliaTemplate = pkgs.writeText "noctalia-heroic.css" ''
    body.noctalia {
      /* Text colors */
      --text-default: {{colors.on_background.default.hex}};
      --text-secondary: {{colors.on_surface_variant.default.hex}};
      --text-tertiary: {{colors.on_primary_container.default.hex}};
      --text-quartenary: {{colors.on_surface.default.hex}};
      --text-hover: {{colors.primary.default.hex}};

      /* Background colors */
      --background: {{colors.surface.default.hex}};
      --background-darker: {{colors.background.default.hex}};
      --background-lighter: {{colors.surface_variant.default.hex}};
      --body-background: {{colors.background.default.hex}};
      --input-background: {{colors.surface_variant.default.hex}};
      --controller-hints-background: transparent;
      --current-background: var(--body-background);
      --modal-background: {{colors.background.default.hex}};
      --modal-backdrop: rgba(0, 0, 0, 0.85);
      --modal-border: {{colors.outline.default.hex}};
      --osk-background: var(--body-background);
      --osk-button-background: var(--input-background);
      --osk-button-border: {{colors.outline.default.hex}};
      --search-bar-background: {{colors.surface.default.hex}};
      --search-bar-border: {{colors.outline.default.hex}};

      /* Action Icons */
      --action-icon: {{colors.on_surface_variant.default.hex}};
      --action-icon-hover: var(--text-hover);
      --action-icon-active: {{colors.primary.default.hex}};
      --icon-disabled: {{colors.surface_variant.default.hex}};
      --icon-disabled-overlay: {{colors.outline.default.hex}};
      --icons-background: {{colors.surface.default.hex}};

      /* Buttons */
      --primary-button: {{colors.primary.default.hex}};
      --secondary-button: {{colors.secondary.default.hex}};
      --button-stroke: {{colors.primary.default.hex}};
      --secondary-button-overlay: {{colors.primary_container.default.hex}};
      --tertiary-button: {{colors.tertiary.default.hex}};
      --tertiary-button-overlay: {{colors.tertiary_container.default.hex}};
      --success-button: #2e7d32;
      --disabled-button: {{colors.surface_variant.default.hex}};
      --disabled-button-overlay: {{colors.outline.default.hex}};
      --play-button: var(--primary-button);
      --install-button: var(--secondary-button);
      --cancel-button: #c62828;
      --cancel-button-overlay: #b71c1c;
      --link-highlight: {{colors.primary.default.hex}};

      /* Sidebar */
      --navbar-active: {{colors.primary.default.hex}};
      --navbar-inactive: {{colors.on_surface_variant.default.hex}};
      --navbar-active-background: {{colors.surface_variant.default.hex}};
      --navbar-accent: {{colors.primary.default.hex}};
      --navbar-background: {{colors.surface.default.hex}};
      --divider: {{colors.outline_variant.default.hex}};

      /* Accents / Status */
      --accent: {{colors.primary.default.hex}};
      --accent-overlay: {{colors.primary_container.default.hex}};
      --success: #2e7d32;
      --success-hover: #1b5e20;
      --status-success: #2e7d32;
      --status-warning: #f57c00;
      --status-warning-hover: #e65100;
      --status-info: {{colors.secondary.default.hex}};
      --status-default: {{colors.primary.default.hex}};
      --status-denied: #c62828;
    }

    body.noctalia {
      font-family: "${lilyaGlass.fonts.sans}", sans-serif !important;
    }

    body.noctalia .sidebar {
      border-right: 1px solid var(--divider) !important;
    }

    body.noctalia .game-card {
      border-radius: ${builtins.toString (builtins.floor lilyaGlass.radius.windows)}px !important;
      overflow: hidden;
      transition: transform 0.2s ease, box-shadow 0.2s ease;
    }

    body.noctalia .game-card:hover {
      transform: translateY(-4px);
      box-shadow: 0 4px 12px var(--divider);
    }
  '';
  zenOverridesTemplate = pkgs.writeText "zen-plasma-overdose-overrides.css" (
    builtins.readFile ../../assets/themes/zen-plasma-overdose-overrides.css
  );
  zenOverridesHook = pkgs.writeShellScript "noctalia-zen-overrides" ''
    set -eu

    config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
    cache_home="''${XDG_CACHE_HOME:-$HOME/.cache}"
    chrome_dir="$config_home/zen/${hostProfile.zen.profilePath}/chrome"
    user_chrome="$chrome_dir/userChrome.css"
    override_css="$cache_home/noctalia/zen-browser/zen-plasma-overdose-overrides.css"
    import_line="@import \"$override_css\";"
    usercontent_css="$cache_home/noctalia/zen-browser/zen-userContent.css"
    temp_file=

    mkdir -p "$chrome_dir"
    touch "$user_chrome"
    temp_file="$(${pkgs.coreutils}/bin/mktemp "$chrome_dir/userChrome.css.XXXXXX")"
    ${pkgs.gnugrep}/bin/grep -Fvx "$import_line" "$user_chrome" > "$temp_file" || true
    printf '%s\n' "$import_line" >> "$temp_file"
    mv "$temp_file" "$user_chrome"

    if [ -f "$usercontent_css" ]; then
      ${pkgs.python3}/bin/python3 -c '
import sys
path = sys.argv[1]
with open(path, "r") as f:
    content = f.read()
if content.startswith("* {"):
    content = content.replace("* {\n  --base:", "@-moz-document url-prefix(\"about:\"), url-prefix(\"chrome://\") {\n  :root {\n  --base:", 1)
    content = content.replace("  --error:            #da4453;\n}", "  --error:            #da4453;\n  }\n}", 1)
    with open(path, "w") as f:
        f.write(content)
' "$usercontent_css"
    fi
  '';

  tomlFormat = pkgs.formats.toml { };
  noctaliaSettings = {
    theme.mode = "light";
    theme.source = "custom";
    theme.custom_palette = "Plasma Overdose";
    theme.templates.enable_builtin_templates = true;
    theme.templates.builtin_ids = [ "btop" "gtk3" "gtk4" "kitty" "niri" ];
    theme.templates.enable_community_templates = true;
    theme.templates.community_ids = [ "zen-browser" "zed" "discord" "steam" "telegram" "yazi" ];

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
        launcher_placement = "floating";
        launcher_position = "center";
        clipboard_placement = "floating";
        clipboard_position = "center";
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
      input_path = "${config.xdg.configHome}/noctalia/templates/darkly-qt.conf";
      output_path = [
        "$XDG_CONFIG_HOME/qt5ct/colors/darkly-noctalia.conf"
        "$XDG_CONFIG_HOME/qt6ct/colors/darkly-noctalia.conf"
      ];
      post_hook = "${config.xdg.configHome}/noctalia/templates/darkly-kde-colors";
      index = 1000;
    };

    theme.templates.user.heroic-noctalia = {
      enabled = true;
      input_path = "${config.xdg.configHome}/noctalia/templates/heroic.css";
      output_path = [
        "$XDG_CONFIG_HOME/heroic/themes/noctalia/noctalia.css"
      ];
      index = 1001;
    };

    theme.templates.user.zen-plasma-overdose-overrides = {
      enabled = true;
      input_path = "${config.xdg.configHome}/noctalia/templates/zen-plasma-overdose-overrides.css";
      output_path = [
        "$XDG_CACHE_HOME/noctalia/zen-browser/zen-plasma-overdose-overrides.css"
      ];
      post_hook = "${config.xdg.configHome}/noctalia/templates/zen-plasma-overdose-overrides";
      index = 2000;
    };

  };
  noctaliaSeed = tomlFormat.generate "noctalia-config.toml" noctaliaSettings;
in
{
  xdg.configFile."heroic/themes/noctalia/noctalia.json".text = builtins.toJSON {
    name = "Noctalia";
    filename = "noctalia.css";
    screenshots = [];
    author = "Antigravity";
  };

  xdg.desktopEntries."dev.noctalia.Noctalia" = {
    name = "Noctalia";
    exec = "noctalia --daemon";
    noDisplay = true;
    terminal = false;
    type = "Application";
    categories = [ "Settings" "DesktopSettings" ];
  };

  xdg.configFile = {
    "noctalia/templates/darkly-qt.conf".source = darklyQtTemplate;
    "noctalia/templates/darkly-kde-colors" = {
      source = darklyColorSchemeHook;
      executable = true;
    };
    "noctalia/templates/heroic.css".source = heroicNoctaliaTemplate;
    "noctalia/templates/zen-plasma-overdose-overrides.css".source = zenOverridesTemplate;
    "noctalia/templates/zen-plasma-overdose-overrides" = {
      source = zenOverridesHook;
      executable = true;
    };
  };

  xdg.dataFile."nixos-config/defaults/noctalia-config.toml".source = noctaliaSeed;

  home.activation.seedNoctaliaConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    config_file=${lib.escapeShellArg "${config.xdg.configHome}/noctalia/config.toml"}

    if [ -L "$config_file" ]; then
      target="$(${pkgs.coreutils}/bin/readlink -f "$config_file" || true)"
      case "$target" in
        /nix/store/*) ${pkgs.coreutils}/bin/rm -f "$config_file" ;;
      esac
    fi

    if [ ! -e "$config_file" ]; then
      ${pkgs.coreutils}/bin/install -Dm600 ${noctaliaSeed} "$config_file"
    fi
  '';

  # Plasma sessions do not run Noctalia continuously, but Zen still imports
  # the last generated community theme. Install the compatibility layer during
  # Home Manager activation as well; the template post-hook keeps it current
  # whenever Noctalia is running.
  home.activation.installZenThemeOverrides = lib.hm.dag.entryAfter [ "seedNoctaliaConfig" ] ''
    cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/noctalia/zen-browser"
    config_file=${lib.escapeShellArg "${config.xdg.configHome}/noctalia/config.toml"}
    template_section='[theme.templates.user.zen-plasma-overdose-overrides]'

    mkdir -p "$cache_dir"
    ${pkgs.coreutils}/bin/install -m644 ${zenOverridesTemplate} \
      "$cache_dir/zen-plasma-overdose-overrides.css"
    ${zenOverridesHook}

    # The main Noctalia config is intentionally app-owned after its first
    # seed. Register only this missing integration and preserve all GUI edits.
    if ! ${pkgs.gnugrep}/bin/grep -Fqx "$template_section" "$config_file"; then
      {
        printf '\n%s\n' "$template_section"
        printf 'enabled = true\n'
        printf 'index = 2000\n'
        printf 'input_path = "%s/noctalia/templates/zen-plasma-overdose-overrides.css"\n' \
          ${lib.escapeShellArg config.xdg.configHome}
        printf 'output_path = ["$XDG_CACHE_HOME/noctalia/zen-browser/zen-plasma-overdose-overrides.css"]\n'
        printf 'post_hook = "%s/noctalia/templates/zen-plasma-overdose-overrides"\n' \
          ${lib.escapeShellArg config.xdg.configHome}
      } >> "$config_file"
    fi
  '';

  programs.noctalia = {
    enable = true;
    customPalettes = {
      "Plasma Overdose" = ../../assets/noctalia/palettes/plasma-overdose.json;
      "Catppuccin Lavender Glass" = ../../assets/noctalia/palettes/catppuccin-lavender-glass.json;
    };
  };
}
