{ config, ... }:

{
  programs.niri.settings.binds = with config.lib.niri.actions; {
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
  };
}
