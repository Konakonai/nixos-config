{ config, hostProfile, lib, lilyaTheme, pkgs, ... }:

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
      --controller-hints-background: {{colors.surface_variant.default.hex}};
      --current-background: var(--body-background);
      --modal-background: {{colors.background.default.hex}};
      --modal-backdrop: rgba(0, 0, 0, ${builtins.toString lilyaTheme.opacity.modalBackdrop});
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
      font-family: "${lilyaTheme.fonts.sans}", sans-serif !important;
    }

    body.noctalia .sidebar {
      border-right: 1px solid var(--divider) !important;
    }

    body.noctalia .game-card {
      border-radius: ${builtins.toString (builtins.floor lilyaTheme.radius.windows)}px !important;
      overflow: hidden;
      transition: transform 0.2s ease, box-shadow 0.2s ease;
    }

    body.noctalia .game-card:hover {
      transform: translateY(-4px);
      box-shadow: 0 4px 12px var(--divider);
    }
  '';
  zenCompatibilityTemplate = pkgs.writeText "zen-noctalia-compatibility.css" (
    lib.replaceStrings
      [ "@disabled-opacity@" "@window-radius@" ]
      [
        (builtins.toString lilyaTheme.opacity.disabled)
        (builtins.toString lilyaTheme.radius.windows)
      ]
      (builtins.readFile ../../assets/themes/zen-noctalia-compatibility.css)
  );
  zenCompatibilityHook = pkgs.writeShellScript "noctalia-zen-compatibility" ''
    set -eu

    config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
    cache_home="''${XDG_CACHE_HOME:-$HOME/.cache}"
    chrome_dir="$config_home/zen/${hostProfile.zen.profilePath}/chrome"
    user_chrome="$chrome_dir/userChrome.css"
    compatibility_css="$cache_home/noctalia/zen-browser/zen-noctalia-compatibility.css"
    import_line="@import \"$compatibility_css\";"
    legacy_import="@import \"$cache_home/noctalia/zen-browser/zen-plasma-overdose-overrides.css\";"
    usercontent_css="$cache_home/noctalia/zen-browser/zen-userContent.css"
    temp_file=

    mkdir -p "$chrome_dir"
    touch "$user_chrome"
    temp_file="$(${pkgs.coreutils}/bin/mktemp "$chrome_dir/userChrome.css.XXXXXX")"
    ${pkgs.gnugrep}/bin/grep -Fvx \
      -e "$import_line" \
      -e "$legacy_import" \
      "$user_chrome" > "$temp_file" || true
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
  noctaliaConfigMigrationPython = pkgs.python3.withPackages (pythonPackages: [
    pythonPackages.tomlkit
  ]);
  noctaliaSettings = {
    theme.mode = lilyaTheme.theme.mode;
    theme.source = lilyaTheme.theme.source;
    theme.custom_palette = lilyaTheme.theme.paletteName;
    theme.templates.enable_builtin_templates = true;
    theme.templates.builtin_ids = [ "btop" "gtk3" "gtk4" "kitty" "niri" ];
    theme.templates.enable_community_templates = true;
    theme.templates.community_ids = [ "zen-browser" "zed" "discord" "steam" "telegram" "yazi" ];

    shell = {
      corner_radius_scale = 1.65;
      font_family = lilyaTheme.fonts.sans;

      animation = {
        enabled = true;
        speed = 0.92;
      };

      shadow = {
        direction = "down";
        alpha = lilyaTheme.shadow.alpha;
      };

      panel = {
        transparency_mode = lilyaTheme.noctalia.panelTransparencyMode;
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
      background_opacity = lilyaTheme.opacity.noctaliaPanels;
      radius = lilyaTheme.radius.panels;
      margin_ends = 180;
      margin_edge = 10;
      padding = 0;
      widget_spacing = 10;
      scale = 1.0;
      shadow = false;
      auto_hide = false;
      reserve_space = true;
      capsule = false;
      start = [
        "launcher"
        "network"
        "bluetooth"
        "mihomo-control"
      ];
      center = [ "workspaces" ];
      end = [ "tray" "notifications" "clipboard" "volume" "brightness" "battery" "clock" "control-center" "session" ];
    };

    notification = {
      background_opacity = lilyaTheme.opacity.noctaliaPopups;
      offset_x = 18;
      offset_y = 12;
    };

    osd = {
      background_opacity = lilyaTheme.opacity.noctaliaPopups;
      offset_x = 18;
      offset_y = 12;
    };

    backdrop = {
      enabled = false;
      blur_intensity = lilyaTheme.effects.backdropBlur;
      tint_intensity = lilyaTheme.effects.backdropTint;
    };

    lockscreen = {
      blur_intensity = lilyaTheme.effects.lockscreenBlur;
      tint_intensity = lilyaTheme.effects.lockscreenTint;
    };

    dock.background_opacity = lilyaTheme.opacity.noctaliaDock;

    plugins = {
      auto_update = "all";
      enabled = [ "mdj2812/mihomo-control" ];
    };

    plugin_settings."mdj2812/mihomo-control" = {
      host = "127.0.0.1";
      port = "9090";
      secret = "";
      use_https = false;
      allow_insecure_tls = false;
      test_url = "https://www.gstatic.com/generate_204";
      refresh_interval = 2;
      panel_placement = "floating";
    };

    widget.mihomo-control = {
      type = "mdj2812/mihomo-control:widget";
      label_content = "mode";
      icon_size = 16;
      icon_color_mode = "status";
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

    theme.templates.user.zen-noctalia-compatibility = {
      enabled = true;
      input_path = "${config.xdg.configHome}/noctalia/templates/zen-noctalia-compatibility.css";
      output_path = [
        "$XDG_CACHE_HOME/noctalia/zen-browser/zen-noctalia-compatibility.css"
      ];
      post_hook = "${config.xdg.configHome}/noctalia/templates/zen-noctalia-compatibility";
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
    "noctalia/templates/zen-noctalia-compatibility.css".source = zenCompatibilityTemplate;
    "noctalia/templates/zen-noctalia-compatibility" = {
      source = zenCompatibilityHook;
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

  # Noctalia keeps GUI changes in an app-owned state overlay. Reconcile the
  # active palette and the small set of visual-effect tokens that this module
  # owns while preserving layout, widgets, shortcuts, and all other GUI state.
  home.activation.reconcileNoctaliaSettings = lib.hm.dag.entryAfter [ "seedNoctaliaConfig" ] ''
    state_file="''${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/settings.toml"

    if [ -f "$state_file" ]; then
      ${noctaliaConfigMigrationPython}/bin/python3 - "$state_file" <<'PY'
import pathlib
import sys

import tomlkit

path = pathlib.Path(sys.argv[1])
document = tomlkit.parse(path.read_text())

theme = document.setdefault("theme", tomlkit.table())
theme["mode"] = "${lilyaTheme.theme.mode}"
theme["source"] = "${lilyaTheme.theme.source}"
theme["custom_palette"] = "${lilyaTheme.theme.paletteName}"

bar = document.setdefault("bar", tomlkit.table()).setdefault("main", tomlkit.table())
bar["background_opacity"] = ${builtins.toString lilyaTheme.opacity.noctaliaPanels}
bar["capsule"] = False
for key in ("capsule_fill", "capsule_radius", "capsule_opacity", "capsule_border"):
    bar.pop(key, None)

dock = document.setdefault("dock", tomlkit.table())
dock["background_opacity"] = ${builtins.toString lilyaTheme.opacity.noctaliaDock}

notification = document.setdefault("notification", tomlkit.table())
notification["background_opacity"] = ${builtins.toString lilyaTheme.opacity.noctaliaPopups}

osd = document.setdefault("osd", tomlkit.table())
osd["background_opacity"] = ${builtins.toString lilyaTheme.opacity.noctaliaPopups}

shell = document.setdefault("shell", tomlkit.table())
shell.setdefault("panel", tomlkit.table())["transparency_mode"] = "${lilyaTheme.noctalia.panelTransparencyMode}"
shell.setdefault("shadow", tomlkit.table())["alpha"] = ${builtins.toString lilyaTheme.shadow.alpha}

backdrop = document.setdefault("backdrop", tomlkit.table())
backdrop["enabled"] = False
backdrop["blur_intensity"] = ${builtins.toString lilyaTheme.effects.backdropBlur}
backdrop["tint_intensity"] = ${builtins.toString lilyaTheme.effects.backdropTint}

lockscreen = document.setdefault("lockscreen", tomlkit.table())
lockscreen["blur_intensity"] = ${builtins.toString lilyaTheme.effects.lockscreenBlur}
lockscreen["tint_intensity"] = ${builtins.toString lilyaTheme.effects.lockscreenTint}

lockscreen_widgets = document.get("lockscreen_widgets", {}).get("widget", {})
for widget in lockscreen_widgets.values():
    settings = widget.get("settings")
    if settings is not None:
        settings["background_opacity"] = ${builtins.toString lilyaTheme.opacity.noctaliaPopups}
        settings["input_opacity"] = ${builtins.toString lilyaTheme.opacity.noctaliaPopups}

plugins = document.setdefault("plugins", tomlkit.table())
plugins["auto_update"] = "all"
for source in plugins.get("source", []):
    source.pop("auto_update", None)

enabled = plugins.setdefault("enabled", tomlkit.array())
if "mdj2812/mihomo-control" not in enabled:
    enabled.append("mdj2812/mihomo-control")

plugin_settings = document.setdefault("plugin_settings", tomlkit.table())
mihomo = plugin_settings.setdefault("mdj2812/mihomo-control", tomlkit.table())
defaults = {
    "host": "127.0.0.1",
    "port": "9090",
    "secret": "",
    "use_https": False,
    "allow_insecure_tls": False,
    "test_url": "https://www.gstatic.com/generate_204",
    "refresh_interval": 2,
    "panel_placement": "floating",
}
for key, value in defaults.items():
    mihomo.setdefault(key, value)

path.write_text(tomlkit.dumps(document))
PY
    fi
  '';

  # Plasma sessions do not run Noctalia continuously, but Zen still imports
  # the last generated community theme. Install the compatibility layer during
  # Home Manager activation as well; the template post-hook keeps it current
  # whenever Noctalia is running.
  home.activation.installZenThemeCompatibility = lib.hm.dag.entryAfter [ "seedNoctaliaConfig" ] ''
    cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/noctalia/zen-browser"
    config_file=${lib.escapeShellArg "${config.xdg.configHome}/noctalia/config.toml"}

    mkdir -p "$cache_dir"
    ${pkgs.coreutils}/bin/install -m644 ${zenCompatibilityTemplate} \
      "$cache_dir/zen-noctalia-compatibility.css"
    ${zenCompatibilityHook}

    # The main Noctalia config is intentionally app-owned after its first
    # seed. Replace the legacy-named template entry and preserve all GUI edits.
    ${noctaliaConfigMigrationPython}/bin/python3 - "$config_file" <<'PY'
import pathlib
import sys

import tomlkit

path = pathlib.Path(sys.argv[1])
document = tomlkit.parse(path.read_text())
theme = document.setdefault("theme", tomlkit.table())
templates = theme.setdefault("templates", tomlkit.table())
user_templates = templates.setdefault("user", tomlkit.table())
user_templates.pop("zen-plasma-overdose-overrides", None)

compatibility = tomlkit.table()
compatibility["enabled"] = True
compatibility["index"] = 2000
compatibility["input_path"] = "${config.xdg.configHome}/noctalia/templates/zen-noctalia-compatibility.css"
compatibility["output_path"] = ["$XDG_CACHE_HOME/noctalia/zen-browser/zen-noctalia-compatibility.css"]
compatibility["post_hook"] = "${config.xdg.configHome}/noctalia/templates/zen-noctalia-compatibility"
user_templates["zen-noctalia-compatibility"] = compatibility

path.write_text(tomlkit.dumps(document))
PY
  '';

  home.activation.removePlasmaOverdoseResidue =
    lib.hm.dag.entryAfter [ "installZenThemeCompatibility" "linkGeneration" ] ''
      rm -f \
        "$HOME/.config/noctalia/palettes/Plasma Overdose.json" \
        "$HOME/.config/noctalia/templates/zen-plasma-overdose-overrides" \
        "$HOME/.config/noctalia/templates/zen-plasma-overdose-overrides.css" \
        "''${XDG_CACHE_HOME:-$HOME/.cache}/noctalia/zen-browser/zen-plasma-overdose-overrides.css" \
        "''${XDG_CACHE_HOME:-$HOME/.cache}/plasma_theme_Plasma-Overdose.kcache"

      rm -rf \
        "$HOME/.local/share/aurorae/themes/Plasma-Overdose" \
        "$HOME/.local/share/color-schemes/PlasmaOverdose.colors" \
        "$HOME/.local/share/flatpak-icons/Plasma-Overdose" \
        "$HOME/.local/share/icons/Plasma-Overdose" \
        "$HOME/.local/share/icons/Plasma-Overdose.backup" \
        "$HOME/.local/share/konsole/Plasma-Overdose.colorscheme" \
        "$HOME/.local/share/plasma/desktoptheme/Plasma-Overdose" \
        "$HOME/.local/share/plasma/look-and-feel/Plasma-Overdose" \
        "$HOME/.local/share/plasma/look-and-feel/overdose" \
        "$HOME/.local/share/sounds/PlasmaOverdose" \
        "$HOME/.local/share/themes/Plasma-Overdose-GTK" \
        "$HOME/.local/share/wallpapers/Plasma-Overdose"
    '';

  home.activation.removeLegacyThemeNames =
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      rm -f \
        "$HOME/.config/noctalia/palettes/Catppuccin Lavender Glass.json" \
        "$HOME/.config/noctalia/palettes/Catppuccin Lavender Glass.json.backup"
      rm -rf "$HOME/.local/share/fcitx5/themes/catppuccin-lavender-glass"
    '';

  programs.noctalia = {
    enable = true;
    customPalettes.${lilyaTheme.theme.paletteName} =
      ../../assets/noctalia/palettes/catppuccin-lavender-light.json;
  };
}
