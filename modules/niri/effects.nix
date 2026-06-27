{ config, hostProfile, pkgs, lib, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
  nvidia = hostProfile.graphics.nvidia or { enable = false; };
  intelDebug = lib.optionalString (nvidia.enable or false) ''
    debug {
        render-drm-device "${nvidia.intelRenderNode}"
        ignore-drm-device "${nvidia.nvidiaRenderNode}"
    }
  '';
  nvidiaDebug = lib.optionalString (nvidia.enable or false) ''
    debug {
        render-drm-device "${nvidia.nvidiaRenderNode}"
        wait-for-frame-completion-before-queueing
    }
  '';

  baseConfig = ''
    ${config.programs.niri.finalConfig}

    include "noctalia.kdl"

    workspace "games"

    window-rule {
        exclude app-id="^kitty$"
        opacity ${lilyaGlass.opacity.windows}
        draw-border-with-background false
    }

    window-rule {
        match app-id="^(wechat|wechat-uos|com\\.tencent\\.WeChat|linuxqq|QQ|wemeetapp|com\\.tencent\\.wemeet)$"
        opacity 1.0
        draw-border-with-background false
    }

    window-rule {
        match app-id="^kitty$"
        draw-border-with-background false
        background-effect {
            blur true
            noise ${lilyaGlass.blur.noise}
            saturation ${lilyaGlass.blur.saturation}
        }
    }

    layer-rule {
        match namespace="^noctalia-bar-main$"
        background-effect {
            blur false
        }
        popups {
            opacity ${lilyaGlass.opacity.layerPopups}
            geometry-corner-radius ${builtins.toString lilyaGlass.radius.windows}
            background-effect {
                blur true
                noise ${lilyaGlass.blur.noise}
                saturation ${lilyaGlass.blur.saturation}
            }
        }
    }

    layer-rule {
        match namespace="^(noctalia-control-center|noctalia-launcher|noctalia-session|noctalia-clipboard|notifications|swaync-control-center|launcher|vicinae|waybar)$"
        opacity ${lilyaGlass.opacity.layerShell}
        geometry-corner-radius ${builtins.toString lilyaGlass.radius.windows}
        background-effect {
            blur true
            noise 0.0
            saturation ${lilyaGlass.blur.saturation}
        }
        popups {
            opacity ${lilyaGlass.opacity.layerPopups}
            geometry-corner-radius ${builtins.toString lilyaGlass.radius.windows}
            background-effect {
                blur true
                noise ${lilyaGlass.blur.noise}
                saturation ${lilyaGlass.blur.saturation}
            }
        }
    }

    layer-rule {
        match namespace="^noctalia-wallpaper.*"
        place-within-backdrop true
    }

    blur {
        passes ${builtins.toString lilyaGlass.blur.passes}
        offset ${lilyaGlass.blur.offset}
        noise ${lilyaGlass.blur.noise}
        saturation ${lilyaGlass.blur.saturation}
    }
  '';
in
{
  xdg.configFile.niri-config.source = lib.mkForce (pkgs.writeText "niri-config.kdl" ''
    ${baseConfig}
    ${intelDebug}
  '');

  xdg.configFile."niri/config-intel.kdl".text = ''
    ${baseConfig}
    ${intelDebug}
  '';

  xdg.configFile."niri/config-nvidia.kdl".text = ''
    ${baseConfig}
    ${nvidiaDebug}
  '';
}
