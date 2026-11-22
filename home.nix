{ hostProfile, inputs, ... }:

{
  imports = [
    inputs.zen-browser.homeModules.beta
    inputs.noctalia.homeModules.default
    inputs.nix-flatpak.homeManagerModules.nix-flatpak
    inputs.plasma-manager.homeModules.plasma-manager
    inputs.spicetify-nix.homeManagerModules.spicetify
  ];

  home = {
    username = hostProfile.user.userName;
    homeDirectory = hostProfile.user.homeDirectory;
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
