{ pkgs, ... }:

{
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    configurationLimit = 30;
    # Prefer the external 4K panel for GRUB and the EFI framebuffer.
    # "auto" is kept as a fallback for boots without the external display.
    gfxmodeEfi = "3840x2160,auto";
    gfxpayloadEfi = "keep";
    theme = pkgs.stdenv.mkDerivation {
      pname = "persona5-joker-grub-theme";
      version = "1.0";
      src = pkgs.fetchFromGitHub {
        owner = "HamzaKarrouchi";
        repo = "Persona_GRUB_Themes";
        rev = "69724f8f5f8e19d064357496088e06166672753f";
        hash = "sha256-SJhGLcZRe8F68fHmS0m3MC3doAQi/PeCYQX2rWbKvtE=";
      };
      installPhase = "cp -r themes/persona5_royal/joker $out";
    };
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "tun" ];
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
    # Keep fbcon on the Philips external panel at native resolution.
    "video=DP-2:3840x2160@60"
    "i915.enable_guc=3"
  ];
  boot.supportedFilesystems.ntfs = true;

  security.allowSimultaneousMultithreading = false;
}
