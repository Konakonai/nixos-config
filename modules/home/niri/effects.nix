{ config, hostProfile, lilyaGlass, pkgs, lib, ... }:

let
  internalDisplay = hostProfile.display.internal;
  externalDisplay = hostProfile.display.external or null;
  kdlString = builtins.toJSON;
  outputName = display: "${display.make} ${display.model} ${display.serial}";
  outputOn = display: focusAtStartup: ''
    output ${kdlString (outputName display)} {
        scale ${builtins.toString display.scale}
        ${lib.optionalString focusAtStartup "focus-at-startup"}
        transform "normal"
        position x=${builtins.toString display.position.x} y=${builtins.toString display.position.y}
    }
  '';
  wildcardOutput = ''
    output "*" {
        scale ${builtins.toString internalDisplay.scale}
        transform "normal"
    }
  '';

  baseConfig = ''
    ${config.programs.niri.finalConfig}

    include "noctalia.kdl"

    window-rule {
        exclude app-id="^kitty$"
        opacity ${lilyaGlass.opacity.windows}
        draw-border-with-background false
    }

    window-rule {
        match app-id="^(wechat|wechat-uos|com\\.tencent\\.WeChat|linuxqq|QQ|wemeetapp|com\\.tencent\\.wemeet)$"
        opacity ${lilyaGlass.opacity.windows}
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
        opacity ${lilyaGlass.opacity.compositorLayers}
        background-effect {
            blur true
            noise ${lilyaGlass.blur.noise}
            saturation ${lilyaGlass.blur.saturation}
        }
        popups {
            opacity ${lilyaGlass.opacity.compositorLayers}
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
        opacity ${lilyaGlass.opacity.compositorLayers}
        geometry-corner-radius ${builtins.toString lilyaGlass.radius.windows}
        background-effect {
            blur true
            noise ${lilyaGlass.blur.noise}
            saturation ${lilyaGlass.blur.saturation}
        }
        popups {
            opacity ${lilyaGlass.opacity.compositorLayers}
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
  sessionConfig = ''
    ${baseConfig}
    ${wildcardOutput}
    ${outputOn internalDisplay false}
    ${lib.optionalString (externalDisplay != null) (outputOn externalDisplay true)}
  '';
in
{
  xdg.configFile.niri-config.source = lib.mkForce (pkgs.writeText "niri-config.kdl" sessionConfig);
}
