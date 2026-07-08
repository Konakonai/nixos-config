{ config, pkgs, ... }:

let
  killFocusedWindow = pkgs.writeShellScript "niri-kill-focused-window" ''
    pid="$(${pkgs.niri}/bin/niri msg -j focused-window | ${pkgs.jq}/bin/jq -r '.pid // empty')"

    case "$pid" in
      ""|*[!0-9]*) exit 0 ;;
    esac

    ${pkgs.coreutils}/bin/kill -TERM "$pid" 2>/dev/null || exit 0
    ${pkgs.coreutils}/bin/sleep 2
    ${pkgs.coreutils}/bin/kill -0 "$pid" 2>/dev/null \
      && ${pkgs.coreutils}/bin/kill -KILL "$pid" 2>/dev/null \
      || true
  '';
in
{
  programs.niri.settings.binds = with config.lib.niri.actions; {
    "Mod+R".action.switch-preset-column-width = [];
    "Mod+Shift+R".action.switch-preset-column-width-back = [];
    "Mod+Ctrl+Shift+R".action.switch-preset-window-height = [];
    "Mod+Ctrl+R".action.reset-window-height = [];
    "Mod+Minus".action.set-column-width = [ "-10%" ];
    "Mod+Equal".action.set-column-width = [ "+10%" ];
    "Mod+Shift+Minus".action.set-window-height = [ "-10%" ];
    "Mod+Shift+Equal".action.set-window-height = [ "+10%" ];

    # PrtSc-free screenshot variants for external keyboards.
    "Mod+Shift+S".action.screenshot = [];
    "Mod+Shift+Ctrl+S".action.screenshot-screen = [];
    "Mod+Shift+Alt+S".action.screenshot-window = [];

    "Print".action.screenshot = [];
    "Ctrl+Print".action.screenshot-screen = [];
    "Alt+Print".action.screenshot-window = [];

    "Ctrl+Alt+Delete".action.spawn = [ "resources" ];
    "Mod+Ctrl+Q".action.spawn = [ "${killFocusedWindow}" ];

    "Mod+Escape".action.spawn = [ "noctalia" "msg" "session" "lock" ];
    "Mod+M".action.spawn = [ "noctalia" "msg" "panel-toggle" "session" ];
    "Mod+N".action.spawn = [ "noctalia" "msg" "panel-toggle" "control-center" "notifications" ];
    "Mod+X".action.spawn = [ "noctalia" "msg" "panel-toggle" "control-center" ];
    "Mod+Shift+C".action.spawn = [ "noctalia" "msg" "panel-toggle" "clipboard" ];
    "Mod+Shift+Q".action.spawn = [ "thermal-profile" "toggle" ];

    "XF86AudioRaiseVolume".action.spawn = [ "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+" ];
    "XF86AudioLowerVolume".action.spawn = [ "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-" ];
    "XF86AudioMute".action.spawn = [ "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle" ];

    "XF86MonBrightnessUp".action.spawn = [ "brightnessctl" "set" "+5%" ];
    "XF86MonBrightnessDown".action.spawn = [ "brightnessctl" "set" "5%-" ];

    "Mod+Shift+E".action.quit = [];
    "Mod+Shift+P".action.power-off-monitors = [];
  };
}
