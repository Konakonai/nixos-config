{ lib, pkgs, configPath }:

pkgs.writeShellApplication {
  name = "codex-update";
  runtimeInputs = with pkgs; [
    coreutils curl gawk git gh gnugrep gnused jq libnotify nix util-linux
  ];
  text = ''
    repo=${lib.escapeShellArg configPath}
  '' + builtins.readFile ../scripts/codex-update.sh;
}
