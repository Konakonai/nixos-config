{ ... }:

{
  imports = [
    ./core.nix
    ./effects.nix
    ./binds/apps.nix
    ./binds/monitors.nix
    ./binds/system.nix
    ./binds/window.nix
    ./binds/workspaces.nix
  ];
}
