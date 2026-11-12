{
  hostProfile,
  lilyaTheme,
  ...
}:

let
  internalDisplay = hostProfile.display.internal;
  externalDisplay = hostProfile.display.external;
  outputName = display: "${display.make} ${display.model} ${display.serial}";
  outputOn = display: focusAtStartup: {
    inherit (display) scale position;
    focus-at-startup = focusAtStartup;
  };
in
{
  programs.niri.settings = {
    blur.enable = false;

    outputs = {
      "*" = {
        inherit (internalDisplay) scale;
      };
      ${outputName internalDisplay} = outputOn internalDisplay false;
      ${outputName externalDisplay} = outputOn externalDisplay true;
    };

    layer-rules = [
      {
        matches = [ { layer = "top"; } ];
        background-effect.xray = false;
      }
      {
        matches = [ { layer = "overlay"; } ];
        background-effect.xray = false;
      }
      {
        matches = [ { namespace = "^noctalia-bar-main$"; } ];
        popups.geometry-corner-radius = lilyaTheme.radius.windows;
      }
      {
        matches = [
          {
            namespace = "^(noctalia-control-center|noctalia-launcher|noctalia-session|noctalia-clipboard|notifications)$";
          }
        ];
        geometry-corner-radius = lilyaTheme.radius.windows;
        popups.geometry-corner-radius = lilyaTheme.radius.windows;
      }
      {
        matches = [ { namespace = "^noctalia-wallpaper.*"; } ];
        place-within-backdrop = true;
      }
    ];
  };
}
