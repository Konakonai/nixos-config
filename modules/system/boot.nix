{ pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "tun" ];
  boot.kernelParams = [ "nvidia-drm.fbdev=1" "i915.enable_guc=3" ];
  boot.supportedFilesystems.ntfs = true;

  security.allowSimultaneousMultithreading = false;
}
