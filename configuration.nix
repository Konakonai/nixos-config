{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/system/audio.nix
    ./modules/system/boot.nix
    ./modules/system/display.nix
    ./modules/system/fonts.nix
    ./modules/system/graphics.nix
    ./modules/system/localization.nix
    ./modules/system/memory.nix
    ./modules/system/networking.nix
    ./modules/system/nix.nix
    ./modules/system/packages.nix
    ./modules/system/power.nix
    ./modules/system/programs.nix
    ./modules/system/services.nix
    ./modules/system/user.nix
  ];

  system.stateVersion = "26.05";
}
