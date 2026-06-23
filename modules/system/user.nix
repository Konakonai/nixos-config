{ pkgs, ... }:

{
  users.users.lilya = {
    isNormalUser = true;
    description = "lilya";
    shell = pkgs.fish;

    extraGroups = [
      "networkmanager"
      "wheel"
      "audio"
      "video"
      "input"
    ];
  };
}
