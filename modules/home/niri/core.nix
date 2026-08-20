{ config, lilyaGlass, pkgs, ... }:

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
    prefer-no-csd = true;

    spawn-at-startup = [
      { command = [ "noctalia" ]; }
      { command = [ "xwayland-satellite" ]; }
      { command = [ "${xwaylandCoreFonts}" ]; }
      { command = [ "xrdb" "-merge" "${config.home.homeDirectory}/.Xresources" ]; }
      { command = [ "wl-paste" "--watch" "cliphist" "store" ]; }
    ];

    hotkey-overlay.skip-at-startup = true;

    cursor = {
      theme = lilyaGlass.cursorThemeName;
      size = lilyaGlass.cursorSize;
    };

    environment = {
      GSK_RENDERER = "gl";
      GTK_USE_PORTAL = "1";
      NIXOS_OZONE_WL = "1";
      QT_QPA_PLATFORMTHEME = "qt6ct";
      QT_WAYLAND_DECORATION = "adwaita";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
      XCURSOR_THEME = lilyaGlass.cursorThemeName;
      XCURSOR_SIZE = builtins.toString lilyaGlass.cursorSize;
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
        active.color = lilyaGlass.palette.lavender;
        inactive.color = lilyaGlass.palette.crust;
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
        color = lilyaGlass.palette.shadow;
      };
    };

    window-rules = [
      {
        geometry-corner-radius = let
          radius = lilyaGlass.radius.windows;
        in {
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
