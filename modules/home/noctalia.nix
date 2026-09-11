{ config, lib, lilyaTheme, pkgs, ... }:

let
  darklyQtTemplate = ../../assets/noctalia/templates/darkly-qt.conf;
  heroicNoctaliaTemplate = pkgs.replaceVars ../../assets/noctalia/templates/heroic.css {
    modalBackdrop = builtins.toString lilyaTheme.opacity.modalBackdrop;
    sansFont = lilyaTheme.fonts.sans;
    windowRadius = builtins.toString (builtins.floor lilyaTheme.radius.windows);
  };
  # Keep this path stable because Noctalia's seed-once config refers to it.
  # The hook only updates Noctalia's standalone color scheme; Plasma owns
  # kdeglobals so changes made in System Settings survive future activations.
  darklyColorSchemeHook = pkgs.writeShellApplication {
    name = "noctalia-darkly-kde-colors";
    runtimeInputs = [ pkgs.gawk pkgs.kdePackages.kconfig pkgs.coreutils ];
    text = builtins.readFile ../../scripts/noctalia-darkly-kde-colors.sh;
  };
  tomlFormat = pkgs.formats.toml { };
  noctaliaConfigMigrationPython = pkgs.python3.withPackages (pythonPackages: [
    pythonPackages.tomlkit
  ]);
  noctaliaSettings = {
    theme.mode = lilyaTheme.theme.mode;
    theme.source = lilyaTheme.theme.source;
    theme.custom_palette = lilyaTheme.theme.paletteName;
    theme.templates.enable_builtin_templates = true;
    theme.templates.builtin_ids = [ "btop" "gtk3" "gtk4" "niri" ];
    theme.templates.enable_community_templates = true;
    theme.templates.community_ids = [ "zen-browser" "discord" "steam" "telegram" "yazi" ];

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
      reserve_space = false;
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

    dock = {
      background_opacity = lilyaTheme.opacity.noctaliaDock;
      reserve_space = false;
    };

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
      source = lib.getExe darklyColorSchemeHook;
      executable = true;
    };
    "noctalia/templates/heroic.css".source = heroicNoctaliaTemplate;
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
      ${noctaliaConfigMigrationPython}/bin/python3 ${../../scripts/reconcile-noctalia.py} \
        ${noctaliaSeed} "$state_file"
    fi
  '';

  programs.noctalia = {
    enable = true;
    customPalettes.${lilyaTheme.theme.paletteName} =
      ../../assets/noctalia/palettes/catppuccin-lavender-light.json;
  };
}
