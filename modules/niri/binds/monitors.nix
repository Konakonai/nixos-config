{ config, ... }:

{
  programs.niri.settings.binds = with config.lib.niri.actions; {
    "Mod+Shift+Left".action.focus-monitor-left = [];
    "Mod+Shift+Right".action.focus-monitor-right = [];
    "Mod+Shift+Up".action.focus-monitor-up = [];
    "Mod+Shift+Down".action.focus-monitor-down = [];
    "Mod+Shift+H".action.focus-monitor-left = [];
    "Mod+Shift+L".action.focus-monitor-right = [];
    "Mod+Shift+K".action.focus-monitor-up = [];
    "Mod+Shift+J".action.focus-monitor-down = [];

    "Mod+Shift+Ctrl+Left".action.move-column-to-monitor-left = [];
    "Mod+Shift+Ctrl+Right".action.move-column-to-monitor-right = [];
    "Mod+Shift+Ctrl+Up".action.move-column-to-monitor-up = [];
    "Mod+Shift+Ctrl+Down".action.move-column-to-monitor-down = [];
    "Mod+Shift+Ctrl+H".action.move-column-to-monitor-left = [];
    "Mod+Shift+Ctrl+L".action.move-column-to-monitor-right = [];
    "Mod+Shift+Ctrl+K".action.move-column-to-monitor-up = [];
    "Mod+Shift+Ctrl+J".action.move-column-to-monitor-down = [];

    "Mod+Alt+H".action.move-workspace-to-monitor-left = [];
    "Mod+Alt+L".action.move-workspace-to-monitor-right = [];
    "Mod+Alt+K".action.move-workspace-to-monitor-up = [];
    "Mod+Alt+J".action.move-workspace-to-monitor-down = [];
  };
}
