{ inputs, ... }:

{
  imports = [
    inputs.zen-browser.homeModules.beta
    inputs.noctalia.homeModules.default
    inputs.nix-flatpak.homeManagerModules.nix-flatpak
    inputs.plasma-manager.homeModules.plasma-manager

    ./apps
    ./beets
    ./cli-tools.nix
    ./codex.nix
    ./config-tools.nix
    ./desktop
    ./dev.nix
    ./fcitx5.nix
    ./flatpak.nix
    ./gaming.nix
    ./kitty.nix
    ./niri
    ./noctalia.nix
    ./shell.nix
    ./services
    ./theme
    ./yazi.nix
    ./zen.nix
  ];
}
