{ config, pkgs, ... }:

let
  killFocusedWindow = pkgs.writeShellScript "niri-kill-focused-window" ''
    niri=${config.programs.niri.package}/bin/niri
    read -r id pid < <("$niri" msg -j focused-window | ${pkgs.jq}/bin/jq -r '"\(.id // "") \(.pid // "")"')

    case "$pid" in
      ""|*[!0-9]*) exit 0 ;;
    esac

    # X11 windows report xwayland-satellite's PID. Killing it takes down
    # every X11 client, and fcitx5 does not reconnect to the new :0, so
    # X11 apps fall back to their own unthemed candidate window.
    case "$(${pkgs.coreutils}/bin/cat "/proc/$pid/comm" 2>/dev/null)" in
      *xwayland-sat*)
        exec "$niri" msg action close-window --id "$id"
        ;;
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
    # Apps & launchers
    "Mod+Shift+Slash".action.show-hotkey-overlay = [ ];
    "Mod+Return".action.spawn = [ "kitty" ];
    "Mod+D".action.spawn = [
      "noctalia"
      "msg"
      "panel-toggle"
      "launcher"
    ];
    "Mod+Space".action.spawn = [
      "noctalia"
      "msg"
      "panel-toggle"
      "launcher"
    ];
    "Mod+O" = {
      repeat = false;
      action.toggle-overview = [ ];
    };

    # Windows & columns
    "Mod+Q" = {
      repeat = false;
      action.close-window = [ ];
    };
    "Mod+F".action.maximize-column = [ ];
    "Mod+Shift+F".action.fullscreen-window = [ ];
    "Mod+C".action.center-column = [ ];
    "Mod+Ctrl+C".action.center-visible-columns = [ ];
    "Mod+Ctrl+F".action.expand-column-to-available-width = [ ];
    "Mod+V".action.toggle-window-floating = [ ];
    "Mod+Shift+V".action.switch-focus-between-floating-and-tiling = [ ];
    "Mod+W".action.toggle-column-tabbed-display = [ ];
    "Mod+Comma".action.consume-window-into-column = [ ];
    "Mod+Period".action.expel-window-from-column = [ ];
    "Mod+BracketLeft".action.consume-or-expel-window-left = [ ];
    "Mod+BracketRight".action.consume-or-expel-window-right = [ ];
    "Mod+Tab".action.focus-window-down = [ ];
    "Mod+Shift+Tab".action.focus-window-up = [ ];

    "Mod+Left".action.focus-column-left = [ ];
    "Mod+Right".action.focus-column-right = [ ];
    "Mod+Up".action.focus-window-or-workspace-up = [ ];
    "Mod+Down".action.focus-window-or-workspace-down = [ ];
    "Mod+H".action.focus-column-left = [ ];
    "Mod+L".action.focus-column-right = [ ];
    "Mod+K".action.focus-window-or-workspace-up = [ ];
    "Mod+J".action.focus-window-or-workspace-down = [ ];
    "Mod+Home".action.focus-column-first = [ ];
    "Mod+End".action.focus-column-last = [ ];

    "Mod+Ctrl+Left".action.move-column-left = [ ];
    "Mod+Ctrl+Right".action.move-column-right = [ ];
    "Mod+Ctrl+Up".action.move-window-up-or-to-workspace-up = [ ];
    "Mod+Ctrl+Down".action.move-window-down-or-to-workspace-down = [ ];
    "Mod+Ctrl+H".action.move-column-left = [ ];
    "Mod+Ctrl+L".action.move-column-right = [ ];
    "Mod+Ctrl+K".action.move-window-up-or-to-workspace-up = [ ];
    "Mod+Ctrl+J".action.move-window-down-or-to-workspace-down = [ ];
    "Mod+Ctrl+Home".action.move-column-to-first = [ ];
    "Mod+Ctrl+End".action.move-column-to-last = [ ];

    "Mod+R".action.switch-preset-column-width = [ ];
    "Mod+Shift+R".action.switch-preset-column-width-back = [ ];
    "Mod+Ctrl+Shift+R".action.switch-preset-window-height = [ ];
    "Mod+Ctrl+R".action.reset-window-height = [ ];
    "Mod+Minus".action.set-column-width = [ "-10%" ];
    "Mod+Equal".action.set-column-width = [ "+10%" ];
    "Mod+Shift+Minus".action.set-window-height = [ "-10%" ];
    "Mod+Shift+Equal".action.set-window-height = [ "+10%" ];

    # Monitors
    "Mod+Shift+Left".action.focus-monitor-left = [ ];
    "Mod+Shift+Right".action.focus-monitor-right = [ ];
    "Mod+Shift+Up".action.focus-monitor-up = [ ];
    "Mod+Shift+Down".action.focus-monitor-down = [ ];
    "Mod+Shift+H".action.focus-monitor-left = [ ];
    "Mod+Shift+L".action.focus-monitor-right = [ ];
    "Mod+Shift+K".action.focus-monitor-up = [ ];
    "Mod+Shift+J".action.focus-monitor-down = [ ];

    "Mod+Shift+Ctrl+Left".action.move-column-to-monitor-left = [ ];
    "Mod+Shift+Ctrl+Right".action.move-column-to-monitor-right = [ ];
    "Mod+Shift+Ctrl+Up".action.move-column-to-monitor-up = [ ];
    "Mod+Shift+Ctrl+Down".action.move-column-to-monitor-down = [ ];
    "Mod+Shift+Ctrl+H".action.move-column-to-monitor-left = [ ];
    "Mod+Shift+Ctrl+L".action.move-column-to-monitor-right = [ ];
    "Mod+Shift+Ctrl+K".action.move-column-to-monitor-up = [ ];
    "Mod+Shift+Ctrl+J".action.move-column-to-monitor-down = [ ];

    "Mod+Alt+H".action.move-workspace-to-monitor-left = [ ];
    "Mod+Alt+L".action.move-workspace-to-monitor-right = [ ];
    "Mod+Alt+K".action.move-workspace-to-monitor-up = [ ];
    "Mod+Alt+J".action.move-workspace-to-monitor-down = [ ];

    # Workspaces & wheel navigation
    "Mod+1".action.focus-workspace = [ 1 ];
    "Mod+2".action.focus-workspace = [ 2 ];
    "Mod+3".action.focus-workspace = [ 3 ];
    "Mod+4".action.focus-workspace = [ 4 ];
    "Mod+5".action.focus-workspace = [ 5 ];
    "Mod+6".action.focus-workspace = [ 6 ];
    "Mod+7".action.focus-workspace = [ 7 ];
    "Mod+8".action.focus-workspace = [ 8 ];
    "Mod+9".action.focus-workspace = [ 9 ];

    "Mod+Ctrl+1".action.move-column-to-workspace = [ 1 ];
    "Mod+Ctrl+2".action.move-column-to-workspace = [ 2 ];
    "Mod+Ctrl+3".action.move-column-to-workspace = [ 3 ];
    "Mod+Ctrl+4".action.move-column-to-workspace = [ 4 ];
    "Mod+Ctrl+5".action.move-column-to-workspace = [ 5 ];
    "Mod+Ctrl+6".action.move-column-to-workspace = [ 6 ];
    "Mod+Ctrl+7".action.move-column-to-workspace = [ 7 ];
    "Mod+Ctrl+8".action.move-column-to-workspace = [ 8 ];
    "Mod+Ctrl+9".action.move-column-to-workspace = [ 9 ];

    "Mod+Page_Up".action.focus-workspace-up = [ ];
    "Mod+Page_Down".action.focus-workspace-down = [ ];
    "Mod+U".action.focus-workspace-down = [ ];
    "Mod+I".action.focus-workspace-up = [ ];
    "Mod+Ctrl+Page_Down".action.move-column-to-workspace-down = [ ];
    "Mod+Ctrl+Page_Up".action.move-column-to-workspace-up = [ ];
    "Mod+Ctrl+U".action.move-column-to-workspace-down = [ ];
    "Mod+Ctrl+I".action.move-column-to-workspace-up = [ ];
    "Mod+Shift+Page_Up".action.move-workspace-up = [ ];
    "Mod+Shift+Page_Down".action.move-workspace-down = [ ];
    "Mod+Shift+U".action.move-workspace-down = [ ];
    "Mod+Shift+I".action.move-workspace-up = [ ];

    "Mod+WheelScrollDown" = {
      cooldown-ms = 150;
      action.focus-workspace-down = [ ];
    };
    "Mod+WheelScrollUp" = {
      cooldown-ms = 150;
      action.focus-workspace-up = [ ];
    };
    "Mod+Ctrl+WheelScrollDown" = {
      cooldown-ms = 150;
      action.move-column-to-workspace-down = [ ];
    };
    "Mod+Ctrl+WheelScrollUp" = {
      cooldown-ms = 150;
      action.move-column-to-workspace-up = [ ];
    };
    "Mod+WheelScrollRight".action.focus-column-right = [ ];
    "Mod+WheelScrollLeft".action.focus-column-left = [ ];
    "Mod+Ctrl+WheelScrollRight".action.move-column-right = [ ];
    "Mod+Ctrl+WheelScrollLeft".action.move-column-left = [ ];

    # Screenshots, shell panels, media & system
    # PrtSc-free screenshot variants for external keyboards.
    "Mod+Shift+S".action.screenshot = [ ];
    "Mod+Shift+Ctrl+S".action.screenshot-screen = [ ];
    "Mod+Shift+Alt+S".action.screenshot-window = [ ];

    "Print".action.screenshot = [ ];
    "Ctrl+Print".action.screenshot-screen = [ ];
    "Alt+Print".action.screenshot-window = [ ];

    "Ctrl+Alt+Delete".action.spawn = [ "resources" ];
    "Mod+Ctrl+Q".action.spawn = [ "${killFocusedWindow}" ];

    "Mod+Escape".action.spawn = [
      "noctalia"
      "msg"
      "session"
      "lock"
    ];
    "Mod+M".action.spawn = [
      "noctalia"
      "msg"
      "panel-toggle"
      "session"
    ];
    "Mod+N".action.spawn = [
      "noctalia"
      "msg"
      "panel-toggle"
      "control-center"
      "notifications"
    ];
    "Mod+X".action.spawn = [
      "noctalia"
      "msg"
      "panel-toggle"
      "control-center"
    ];
    "Mod+Shift+C".action.spawn = [
      "noctalia"
      "msg"
      "panel-toggle"
      "clipboard"
    ];
    "Mod+Shift+Q".action.spawn = [
      "thermal-profile"
      "toggle"
    ];

    "XF86AudioRaiseVolume".action.spawn = [
      "wpctl"
      "set-volume"
      "@DEFAULT_AUDIO_SINK@"
      "5%+"
    ];
    "XF86AudioLowerVolume".action.spawn = [
      "wpctl"
      "set-volume"
      "@DEFAULT_AUDIO_SINK@"
      "5%-"
    ];
    "XF86AudioMute".action.spawn = [
      "wpctl"
      "set-mute"
      "@DEFAULT_AUDIO_SINK@"
      "toggle"
    ];

    "XF86MonBrightnessUp".action.spawn = [
      "brightnessctl"
      "set"
      "+5%"
    ];
    "XF86MonBrightnessDown".action.spawn = [
      "brightnessctl"
      "set"
      "5%-"
    ];

    "Mod+Shift+E".action.quit = [ ];
    "Mod+Shift+P".action.power-off-monitors = [ ];
  };
}
