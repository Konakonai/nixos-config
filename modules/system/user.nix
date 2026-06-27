{ hostProfile, pkgs, ... }:

{
  users.users.${hostProfile.user.userName} = {
    isNormalUser = true;
    description = hostProfile.user.userName;
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
