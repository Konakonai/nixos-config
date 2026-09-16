{ config, lib, lilyaTheme, pkgs, ... }:

let
  niriFloatOverlay = pkgs.writeShellApplication {
    name = "niri-float-overlay";
    runtimeInputs = [ pkgs.python3 config.programs.niri.package pkgs.libx11 pkgs.libxext ];
    text = ''
      export NIRI_FLOAT_OVERLAY_LIBX11="${pkgs.libx11}/lib/libX11.so.6"
      export NIRI_FLOAT_OVERLAY_LIBXEXT="${pkgs.libxext}/lib/libXext.so.6"
      exec python3 ${../../../scripts/niri-float-overlay.py} "$@"
    '';
  };
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
  home.packages = [ niriFloatOverlay ];

  systemd.user.services.niri-float-overlay = {
    Unit = {
      Description = "Float Steam overlay pets and keep their click region";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = lib.getExe niriFloatOverlay;
      Restart = "always";
      RestartSec = "2s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  programs.niri.settings = {
    includes = [
      { path = "gpu.kdl"; optional = true; }
      { path = "noctalia.kdl"; optional = true; }
    ];

    prefer-no-csd = true;

    spawn-at-startup = [
      { command = [ "noctalia" ]; }
      { command = [ "${xwaylandCoreFonts}" ]; }
      { command = [ "xrdb" "-merge" "${config.home.homeDirectory}/.Xresources" ]; }
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
      gaps = 18;
      struts = {
        top = 48;
        bottom = 56;
      };
      center-focused-column = "never";
      background-color = "transparent";

      preset-column-widths = [
        { proportion = 0.25; }
        { proportion = 0.5; }
        { proportion = 0.75; }
        { proportion = 1.0; }
      ];

      default-column-width = { proportion = 0.5; };

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
        geometry-corner-radius = let
          radius = lilyaTheme.radius.windows;
        in {
          top-left = radius;
          top-right = radius;
          bottom-left = radius;
          bottom-right = radius;
        };
        draw-border-with-background = false;
        clip-to-geometry = true;
      }
      {
        # Steam 4564320 / Your Coworker is a per-pixel desktop overlay.
        matches = [
          { app-id = "^steam_app_4564320$"; }
          { app-id = "^YourCoworker[.]exe$"; }
          { title = "YourCoworker|Your Coworker|With Your Coworker"; }
        ];
        open-floating = true;
        open-fullscreen = false;
        open-focused = false;
        clip-to-geometry = false;
        # Keep the compositor on the blending path so unfocused ARGB is not flattened.
        opacity = 0.99;
        draw-border-with-background = false;
        focus-ring.enable = false;
        shadow.enable = false;
      }
    ];

    animations.enable = true;
  };
}
