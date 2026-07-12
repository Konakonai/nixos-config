{ inputs, hostProfile, ... }:

{
  imports = [
    inputs.zen-browser.homeModules.beta
    inputs.noctalia.homeModules.default
    inputs.nix-flatpak.homeManagerModules.nix-flatpak

    ./modules/home/fcitx5.nix

    ./modules/home/apps.nix
    ./modules/home/cli-tools.nix
    ./modules/home/config-tools.nix
    ./modules/home/codex.nix
    ./modules/home/dev.nix
    ./modules/home/desktop
    ./modules/home/flatpak.nix
    ./modules/home/gaming.nix
    ./modules/home/kitty.nix
    ./modules/home/noctalia.nix
    ./modules/home/niri
    ./modules/home/shell.nix
    ./modules/home/theme
    ./modules/home/yazi.nix
    ./modules/home/zen.nix

  ];

  home = {
    username = hostProfile.user.userName;
    homeDirectory = hostProfile.user.homeDirectory;
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
