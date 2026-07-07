{ config, hostProfile, lib, ... }:

let
  nvidia = hostProfile.graphics.nvidia or { enable = false; };
  # Keep the production driver current while this flake's nixpkgs pin still
  # exposes 595.71.05.
  nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.mkDriver {
    version = "595.84";
    sha256_64bit = "sha256-mcQE5SExvye8ptoCaNzOPr7cenOrF0BxqZXPGmxeugY=";
    openSha256 = "sha256-pEmA2tUcOKwUPKy6N0QvS49Pdut4/7Phs/JhjdyBcNY=";
    settingsSha256 = "sha256-QrnBM+sdWO4GanO62rxpHmRrjYkYpl5RD6fIiHq4C4A=";
    persistencedSha256 = "sha256-50xYdgx7EEThbaMp4QS8GADbxj0mhBXh8QQN0tWMwRg=";
  };
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
      # Keep the regular profile focused on dGPU reliability. The
      # battery-saver specialisation disables NVIDIA entirely when power saving
      # matters, so avoid RTD3/runtime power management here.
      enable = false;
      finegrained = false;
    };

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      intelBusId = nvidia.intelBusId;
      nvidiaBusId = nvidia.nvidiaBusId;
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
