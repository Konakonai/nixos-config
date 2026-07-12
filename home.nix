{ hostProfile, ... }:

{
  imports = [
    ./modules/home
  ];

  home = {
    username = hostProfile.user.userName;
    homeDirectory = hostProfile.user.homeDirectory;
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
