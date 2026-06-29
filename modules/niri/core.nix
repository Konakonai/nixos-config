{ config, pkgs, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
  steamGameBarGuard = pkgs.writeShellScript "steam-game-bar-guard" ''
    set -euo pipefail

    niri="${config.programs.niri.package}/bin/niri"
    noctalia="${config.programs.noctalia.package}/bin/noctalia"
    jq="${pkgs.jq}/bin/jq"
    state="shown"

    update_bar() {
      app_id="$("$niri" msg --json focused-window 2>/dev/null | "$jq" -r '.app_id // ""' 2>/dev/null || true)"

      case "$app_id" in
        steam_app_*)
          if [ "$state" != "hidden" ]; then
            "$noctalia" msg bar-hide main >/dev/null 2>&1 || true
            state="hidden"
          fi
          ;;
        *)
          if [ "$state" != "shown" ]; then
            "$noctalia" msg bar-show main >/dev/null 2>&1 || true
            state="shown"
          fi
          ;;
      esac
    }

    trap '"$noctalia" msg bar-show main >/dev/null 2>&1 || true' EXIT

    update_bar
    while IFS= read -r _; do
      update_bar
    done < <("$niri" msg --json event-stream)
  '';
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
  systemd.user.services.steam-game-bar-guard = {
    Unit = {
      Description = "Hide Noctalia bar while focused Steam games run";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${steamGameBarGuard}";
      Restart = "on-failure";
      RestartSec = "2s";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };

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
      size = 48;
    };

    environment = {
      GTK_USE_PORTAL = "1";
      NIXOS_OZONE_WL = "1";
      QT_QPA_PLATFORMTHEME = "qt6ct";
      QT_WAYLAND_DECORATION = "adwaita";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
      XCURSOR_THEME = lilyaGlass.cursorThemeName;
      XCURSOR_SIZE = "48";
    };

    input = {
      keyboard.xkb = {
        layout = "us";
        options = "";
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
      {
        matches = [
          { app-id = "^steam_app_.*$"; }
        ];
        open-on-workspace = "games";
        open-fullscreen = true;
        geometry-corner-radius = {
          top-left = 0.0;
          top-right = 0.0;
          bottom-left = 0.0;
          bottom-right = 0.0;
        };
        clip-to-geometry = false;
        draw-border-with-background = false;
      }
    ];

    animations.enable = true;
  };
}
