{ config, ... }:

{
  programs.niri.settings.binds = with config.lib.niri.actions; {
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
  };
}
