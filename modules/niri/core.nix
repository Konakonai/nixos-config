{ config, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
in
{
  programs.niri.settings = {
    prefer-no-csd = true;

    spawn-at-startup = [
      { command = [ "noctalia" ]; }
      { command = [ "xwayland-satellite" ]; }
      { command = [ "xrdb" "-merge" "${config.home.homeDirectory}/.Xresources" ]; }
      { command = [ "wl-paste" "--watch" "cliphist" "store" ]; }
    ];

    hotkey-overlay.skip-at-startup = true;

    cursor = {
      theme = lilyaGlass.cursorThemeName;
      size = 48;
    };

    environment = {
      GTK_THEME = lilyaGlass.gtkThemeName;
      GTK_USE_PORTAL = "1";
      NIXOS_OZONE_WL = "1";
      QT_QPA_PLATFORMTHEME = "kvantum";
      QT_STYLE_OVERRIDE = lilyaGlass.qtStyleName;
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

    outputs = {
      "eDP-1" = {
        mode = {
          width = 3200;
          height = 2000;
          refresh = 60.0;
        };
        scale = 1.75;
        position = {
          x = 0;
          y = 0;
        };
      };

      "Philips Consumer Electronics Company PHL 27E2F7901 UHB2341003696" = {
        focus-at-startup = true;
        mode = {
          width = 3840;
          height = 2160;
          refresh = 60.0;
        };
        scale = 1.5;
        position = {
          x = 1828;
          y = 0;
        };
      };
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
