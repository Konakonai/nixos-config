{ config, hostProfile, lib, ... }:

let
  nvidia = hostProfile.graphics.nvidia or { enable = false; };
  nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.stable;
in
{

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
} // lib.optionalAttrs (nvidia.enable or false) {
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;

    powerManagement = {
      enable = true;
      finegrained = true;
    };

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      intelBusId = nvidia.intelBusId;
      nvidiaBusId = "PCI:${toString nvidia.pci.bus}:${toString nvidia.pci.device}:${toString nvidia.pci.function}";
    };

    package = nvidiaPackage;
  };

  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text = builtins.toJSON {
    rules = [
      {
        pattern = { feature = "procname"; matches = "niri"; };
        profile = "Limit Free Buffer Pool On Wayland Compositors";
      }
    ];
    profiles = [
      {
        name = "Limit Free Buffer Pool On Wayland Compositors";
        settings = [
          { key = "GLVidHeapReuseRatio"; value = 0; }
        ];
      }
    ];
  };
}
