{ hostProfile, ... }:

{
  imports = [
    hostProfile.hardwareConfiguration
    ./modules/system
  ];

  system.stateVersion = "26.05";
}
