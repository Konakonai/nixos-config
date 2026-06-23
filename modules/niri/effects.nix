{ config, pkgs, lib, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
in
{
  xdg.configFile.niri-config.source = lib.mkForce (pkgs.writeText "niri-config.kdl" ''
    ${config.programs.niri.finalConfig}

    include "noctalia.kdl"

    debug {
        render-drm-device "/dev/dri/renderD128"
    }

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
    }

    layer-rule {
        match namespace="^noctalia-bar-main$"
        opacity ${lilyaGlass.opacity.noctaliaPanels}
        geometry-corner-radius ${builtins.toString lilyaGlass.radius.panels}
        background-effect {
            blur true
            noise 0.0
            saturation 1.0
        }
        popups {
            opacity ${lilyaGlass.opacity.layerPopups}
            geometry-corner-radius ${builtins.toString lilyaGlass.radius.windows}
            background-effect {
                blur true
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
            saturation 1.0
        }
        popups {
            opacity ${lilyaGlass.opacity.layerPopups}
            geometry-corner-radius ${builtins.toString lilyaGlass.radius.windows}
            background-effect {
                blur true
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
  '');
}
