{
  config,
  lilyaTheme,
  pkgs,
  ...
}:

let
  xwaylandCoreFonts = pkgs.writeShellScript "xwayland-core-fonts" ''
    set -euo pipefail

    xset="${pkgs.xset}/bin/xset"
    font_dir="${pkgs.unifont}/share/fonts"

    for _ in {1..50}; do
      if "$xset" q >/dev/null 2>&1; then
        "$xset" -fp "$font_dir" >/dev/null 2>&1 || true
        "$xset" +fp "$font_dir" >/dev/null 2>&1 || true
        "$xset" fp rehash >/dev/null 2>&1 || true
        exit 0
      fi

      sleep 0.2
    done
  '';
in
{
  programs.niri.settings = {
    # niri-flake treats non-store include paths as optional by default.
    includes = [
      "gpu.kdl"
      "noctalia.kdl"
    ];

    prefer-no-csd = true;

    spawn-at-startup = [
      { command = [ "noctalia" ]; }
      { command = [ "${xwaylandCoreFonts}" ]; }
      {
        command = [
          "xrdb"
          "-merge"
          "${config.home.homeDirectory}/.Xresources"
        ];
      }
    ];

    hotkey-overlay.skip-at-startup = true;

    cursor = {
      theme = lilyaTheme.cursorThemeName;
      size = lilyaTheme.cursorSize;
    };

    environment = {
      GSK_RENDERER = "gl";
      GTK_USE_PORTAL = "1";
      NIXOS_OZONE_WL = "1";
      QT_QPA_PLATFORMTHEME = "qt6ct";
      QT_WAYLAND_DECORATION = "adwaita";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
      # Keep niri's decoration and tiled-size preferences out of Plasma.
      # kitty.conf imports these values with `envinclude KITTY_CONF_*`.
      KITTY_CONF_NIRI_DECORATIONS = "hide_window_decorations yes";
      KITTY_CONF_NIRI_WINDOW_SIZE = "remember_window_size no";
      XCURSOR_THEME = lilyaTheme.cursorThemeName;
      XCURSOR_SIZE = builtins.toString lilyaTheme.cursorSize;
      XCURSOR_PATH = "${pkgs.catppuccin-cursors.frappeLavender}/share/icons:${pkgs.adwaita-icon-theme}/share/icons";
    };

    input = {
      keyboard.xkb = {
        layout = "us";
        options = "caps:super";
      };

      touchpad = {
        tap = true;
        natural-scroll = true;
      };

      mouse.natural-scroll = false;
    };

    layout = {
      # The Noctalia bar and dock reserve their own exclusive zones. Struts only
      # shrink tiled columns, while windows maximized to edges (titlebar
      # maximize button) fill the output minus exclusive zones, so struts alone
      # let those slide under the bar and dock. The dock's zone (64 + 8 margin)
      # is larger than the gap tiled windows need above its visible pill, so a
      # negative bottom strut keeps them ending just above it.
      gaps = 18;
      struts.bottom = -16;
      center-focused-column = "never";
      background-color = "transparent";

      preset-column-widths = [
        { proportion = 0.25; }
        { proportion = 0.5; }
        { proportion = 0.75; }
        { proportion = 1.0; }
      ];

      default-column-width = {
        proportion = 0.5;
      };

      focus-ring = {
        enable = true;
        width = 2;
        active.color = lilyaTheme.palette.lavender;
        inactive.color = lilyaTheme.palette.crust;
      };

      border.enable = false;

      shadow = {
        enable = true;
        softness = 28;
        spread = 4;
        offset = {
          x = 0;
          y = 10;
        };
        color = lilyaTheme.palette.shadow;
      };
    };

    window-rules = [
      {
        geometry-corner-radius =
          let
            radius = lilyaTheme.radius.windows;
          in
          {
            top-left = radius;
            top-right = radius;
            bottom-left = radius;
            bottom-right = radius;
          };
        draw-border-with-background = false;
        clip-to-geometry = true;
      }
    ];

    animations.enable = true;
  };
}
