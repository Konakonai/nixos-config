{ ... }:

{
  imports = [
    ./niri/core.nix
    ./niri/effects.nix
    ./niri/binds/apps.nix
    ./niri/binds/monitors.nix
    ./niri/binds/system.nix
    ./niri/binds/window.nix
    ./niri/binds/workspaces.nix
  ];
}
