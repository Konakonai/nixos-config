{ inputs, hostProfile, ... }:

{
  imports = [
    inputs.zen-browser.homeModules.beta
    inputs.noctalia.homeModules.default
    inputs.nix-flatpak.homeManagerModules.nix-flatpak

    ./modules/glass.nix
    ./modules/fcitx5.nix

    ./modules/home/apps.nix
    ./modules/home/cli-tools.nix
    ./modules/home/dev.nix
    ./modules/home/noctalia.nix
    ./modules/home/yazi.nix
    ./modules/home/zen.nix

    ./modules/niri.nix
    ./modules/kitty.nix
    ./modules/shell.nix
    ./modules/theme.nix
    ./modules/hermes-skin.nix
    ./modules/desktop.nix
    ./modules/codex.nix
    ./modules/flatpak.nix
  ];

  home = {
    username = hostProfile.user.userName;
    homeDirectory = hostProfile.user.homeDirectory;
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
