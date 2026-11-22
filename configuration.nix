{ hostProfile, ... }:

{
  imports = [
    hostProfile.hardwareConfiguration
    ./modules
  ];

  system.stateVersion = "26.05";
}
