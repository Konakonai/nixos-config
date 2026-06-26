{ pkgs, ... }:

let
  touhouGrubTheme = pkgs.stdenvNoCC.mkDerivation {
    pname = "grub-theme-touhou-project";
    version = "2023-04-19";

    src = pkgs.fetchzip {
      url = "https://github.com/13atm01/GRUB-Theme/releases/download/Tproject-v1.0/Touhou_Project.tar.gz";
      hash = "sha256-GcB4Drad77Ndd9LnNA+ZHzjnE4Rm+IwP9FDKLQodxTo=";
      stripRoot = false;
    };

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      mkdir -p "$out"
      cp -r "$src/Touhou Project/Touhou-project/." "$out/"
      test -f "$out/theme.txt"
    '';

    meta = {
      description = "Touhou Project GRUB theme from 13atm01/GRUB-Theme";
      homepage = "https://github.com/13atm01/GRUB-Theme";
      license = pkgs.lib.licenses.gpl3;
      platforms = pkgs.lib.platforms.all;
    };
  };
in
{
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    configurationLimit = 30;
    gfxmodeEfi = "2560x1440,1920x1080,auto";
    gfxpayloadEfi = "keep";
    theme = touhouGrubTheme;
    # Keep large kernel/initrd artifacts off the small ESP. GRUB writes its
    # boot files under /boot-grub on the root filesystem, while /boot remains
    # only the EFI system partition.
    mirroredBoots = [
      {
        path = "/boot-grub";
        efiSysMountPoint = "/boot";
        efiBootloaderId = "NixOS-boot";
        devices = [ "nodev" ];
      }
    ];
    copyKernels = false;
    extraInstallCommands = ''
      grubBootId="$(
        ${pkgs.efibootmgr}/bin/efibootmgr \
          | ${pkgs.gawk}/bin/awk '/NixOS-boot|NixOS Boot Manager/ { id = $1; sub(/^Boot/, "", id); sub(/\*.*/, "", id); print id; exit }'
      )"

      if [ -n "$grubBootId" ]; then
        currentOrder="$(${pkgs.efibootmgr}/bin/efibootmgr | ${pkgs.gnused}/bin/sed -n 's/^BootOrder: //p')"
        restOrder="$(
          printf '%s\n' "$currentOrder" \
            | ${pkgs.gnused}/bin/sed \
                -e "s/^$grubBootId,//" \
                -e "s/,$grubBootId,/,/" \
                -e "s/,$grubBootId$//" \
                -e "s/^$grubBootId$//"
        )"

        if [ -n "$restOrder" ]; then
          desiredOrder="$grubBootId,$restOrder"
        else
          desiredOrder="$grubBootId"
        fi

        if [ -n "$currentOrder" ] && [ "$currentOrder" != "$desiredOrder" ]; then
          ${pkgs.efibootmgr}/bin/efibootmgr -o "$desiredOrder"
        fi
      fi
    '';
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "tun" ];
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.plymouth = {
    enable = true;
    theme = "catppuccin-mocha";
    themePackages = [
      (pkgs.catppuccin-plymouth.override { variant = "mocha"; })
    ];
  };
  boot.kernelParams = [
    "quiet"
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
    "video=DP-2:3840x2160@60e"
    "video=eDP-1:d"
    "i915.enable_guc=3"
    "udev.log_level=3"
  ];
  boot.supportedFilesystems.ntfs = true;

  environment.systemPackages = [ pkgs.efibootmgr ];

  security.allowSimultaneousMultithreading = false;
}
