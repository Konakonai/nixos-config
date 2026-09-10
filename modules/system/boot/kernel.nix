{ hostProfile, pkgs, ... }:

{
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [ "tun" ];
    blacklistedKernelModules = hostProfile.kernel.blacklistedModules or [ ];
  };
}
