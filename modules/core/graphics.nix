{
  config,
  hostProfile,
  pkgs,
  ...
}:

let
  inherit (hostProfile.graphics) nvidia;
  nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.stable;
in
{

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = [ pkgs.intel-media-driver ];
  };

  # Without an Intel VA-API driver, libva fell back to nvidia-vaapi-driver, which
  # creates a CUDA context and pins the dGPU in D0. Qt Multimedia's FFmpeg backend
  # probes VA-API on every QMediaPlayer, so kdeconnectd's findthisdevice plugin
  # kept the dGPU awake for days (~24 W vs ~12 W on battery). FFmpeg opens
  # renderD128 (NVIDIA) first, so the driver has to be forced by name; NVIDIA
  # VA-API stays available via LIBVA_DRIVER_NAME=nvidia.
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

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

  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text =
    builtins.toJSON {
      rules = [
        {
          pattern = {
            feature = "procname";
            matches = "niri";
          };
          profile = "Limit Free Buffer Pool On Wayland Compositors";
        }
      ];
      profiles = [
        {
          name = "Limit Free Buffer Pool On Wayland Compositors";
          settings = [
            {
              key = "GLVidHeapReuseRatio";
              value = 0;
            }
          ];
        }
      ];
    };
}
