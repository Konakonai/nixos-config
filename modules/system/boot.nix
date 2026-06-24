{ pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "tun" ];
  boot.initrd.kernelModules = [ "i915" "xe" "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  boot.kernelParams = [ "nvidia-drm.fbdev=1" ];
}
