{ config, ... }:

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

    "Mod+Shift+S".action.screenshot = [];
    "Print".action.screenshot = [];
    "Ctrl+Print".action.screenshot-screen = [];
    "Alt+Print".action.screenshot-window = [];

    "Mod+Escape".action.spawn = [ "noctalia" "msg" "session" "lock" ];
    "Mod+M".action.spawn = [ "noctalia" "msg" "panel-toggle" "session" ];
    "Mod+N".action.spawn = [ "noctalia" "msg" "panel-toggle" "control-center" "notifications" ];
    "Mod+X".action.spawn = [ "noctalia" "msg" "panel-toggle" "control-center" ];
    "Mod+Shift+C".action.spawn = [ "noctalia" "msg" "panel-toggle" "clipboard" ];

    "XF86AudioRaiseVolume".action.spawn = [ "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+" ];
    "XF86AudioLowerVolume".action.spawn = [ "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-" ];
    "XF86AudioMute".action.spawn = [ "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle" ];

    "XF86MonBrightnessUp".action.spawn = [ "brightnessctl" "set" "+5%" ];
    "XF86MonBrightnessDown".action.spawn = [ "brightnessctl" "set" "5%-" ];

    "Mod+Shift+E".action.quit = [];
    "Mod+Shift+P".action.power-off-monitors = [];
  };
}
