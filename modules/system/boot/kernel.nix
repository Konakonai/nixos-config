{ hostProfile, pkgs, ... }:

{
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [ "tun" ];
    blacklistedKernelModules = hostProfile.kernel.blacklistedModules or [ ];

    kernelParams = [
      # Prefer stable USB input latency over runtime power savings. Device-level
      # udev rules in power/device-rules.nix also enforce this after hotplug.
      "usbcore.autosuspend=-1"
    ];
  };

  security.allowSimultaneousMultithreading = false;
}
