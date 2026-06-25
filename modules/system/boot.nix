{ pkgs, ... }:

{
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    configurationLimit = 30;
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
  boot.kernelParams = [ "nvidia-drm.modeset=1" "nvidia-drm.fbdev=1" "i915.enable_guc=3" ];
  boot.supportedFilesystems.ntfs = true;

  security.allowSimultaneousMultithreading = false;
}
