{ inputs, ... }:

{
  imports = [
    inputs.zen-browser.homeModules.beta
    inputs.noctalia.homeModules.default
    inputs.nix-flatpak.homeManagerModules.nix-flatpak

    ./apps.nix
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
    ./theme
    ./yazi.nix
    ./zen.nix
  ];
}
