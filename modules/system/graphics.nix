{ config, hostProfile, lib, ... }:

let
  nvidia = hostProfile.graphics.nvidia or { enable = false; };
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
    open = false;
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
      nvidiaBusId = nvidia.nvidiaBusId;
    };

    package = config.boot.kernelPackages.nvidiaPackages.stable;
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
