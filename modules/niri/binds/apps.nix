{ config, lib, fcitxEnv, ... }:

let
  fcitxCommand = command:
    [ "env" ]
    ++ lib.mapAttrsToList (name: value: "${name}=${value}") fcitxEnv
    ++ command;
in
{
  programs.niri.settings.binds = with config.lib.niri.actions; {
    "Mod+Shift+Slash".action.show-hotkey-overlay = [];
    "Mod+Return".action.spawn = fcitxCommand [ "kitty" ];
    "Mod+D".action.spawn = [ "noctalia" "msg" "panel-toggle" "launcher" ];
    "Mod+Space".action.spawn = [ "noctalia" "msg" "panel-toggle" "launcher" ];
    "Mod+O" = {
      repeat = false;
      action.toggle-overview = [];
    };

    "Mod+Ctrl+A".action.spawn = [ "codex-desktop" "--appshot" ];
  };
}
