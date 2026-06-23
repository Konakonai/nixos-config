{ config, ... }:

{
  programs.niri.settings.binds = with config.lib.niri.actions; {
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

    "Mod+Page_Up".action.focus-workspace-up = [];
    "Mod+Page_Down".action.focus-workspace-down = [];
    "Mod+U".action.focus-workspace-down = [];
    "Mod+I".action.focus-workspace-up = [];
    "Mod+Ctrl+Page_Down".action.move-column-to-workspace-down = [];
    "Mod+Ctrl+Page_Up".action.move-column-to-workspace-up = [];
    "Mod+Ctrl+U".action.move-column-to-workspace-down = [];
    "Mod+Ctrl+I".action.move-column-to-workspace-up = [];
    "Mod+Shift+Page_Up".action.move-workspace-up = [];
    "Mod+Shift+Page_Down".action.move-workspace-down = [];
    "Mod+Shift+U".action.move-workspace-down = [];
    "Mod+Shift+I".action.move-workspace-up = [];

    "Mod+WheelScrollDown" = {
      cooldown-ms = 150;
      action.focus-workspace-down = [];
    };
    "Mod+WheelScrollUp" = {
      cooldown-ms = 150;
      action.focus-workspace-up = [];
    };
    "Mod+Ctrl+WheelScrollDown" = {
      cooldown-ms = 150;
      action.move-column-to-workspace-down = [];
    };
    "Mod+Ctrl+WheelScrollUp" = {
      cooldown-ms = 150;
      action.move-column-to-workspace-up = [];
    };
    "Mod+WheelScrollRight".action.focus-column-right = [];
    "Mod+WheelScrollLeft".action.focus-column-left = [];
    "Mod+Ctrl+WheelScrollRight".action.move-column-right = [];
    "Mod+Ctrl+WheelScrollLeft".action.move-column-left = [];
  };
}
