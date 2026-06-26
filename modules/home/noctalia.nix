{ inputs, pkgs, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
  noctaliaPackage = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../../patches/noctalia-bar-blur-glass-only.patch
    ];
  });
in
{
  programs.noctalia = {
    enable = true;
    package = noctaliaPackage;

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
    };
  };
}
