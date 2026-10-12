{
  config,
  hostProfile,
  lilyaTheme,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  internalDisplay = hostProfile.display.internal;
  externalDisplay = hostProfile.display.external;
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

    blur {
        off
    }

    window-rule {
        draw-border-with-background false
    }

    layer-rule {
        match layer="top"
        background-effect {
            xray false
        }
    }

    layer-rule {
        match layer="overlay"
        background-effect {
            xray false
        }
    }

    layer-rule {
        match namespace="^noctalia-bar-main$"
        popups {
            geometry-corner-radius ${builtins.toString lilyaTheme.radius.windows}
        }
    }

    layer-rule {
        match namespace="^(noctalia-control-center|noctalia-launcher|noctalia-session|noctalia-clipboard|notifications)$"
        geometry-corner-radius ${builtins.toString lilyaTheme.radius.windows}
        popups {
            geometry-corner-radius ${builtins.toString lilyaTheme.radius.windows}
        }
    }

    layer-rule {
        match namespace="^noctalia-wallpaper.*"
        place-within-backdrop true
    }
  '';
  sessionConfig = ''
    ${baseConfig}
    ${wildcardOutput}
    ${outputOn internalDisplay false}
    ${outputOn externalDisplay true}
  '';
in
{
  xdg.configFile.niri-config.source = lib.mkForce (
    inputs.niri.lib.internal.validated-config-for pkgs config.programs.niri.package sessionConfig
  );
}
