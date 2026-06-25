{ pkgs, ... }:

{
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    configurationLimit = 30;
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
  # Load DRM drivers before userspace so fbcon does not stay on the firmware
  # framebuffer's internal-panel mode during early boot checks.
  boot.initrd.kernelModules = [ "i915" "xe" "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  boot.kernelParams = [ "nvidia-drm.modeset=1" "nvidia-drm.fbdev=1" "i915.enable_guc=3" ];
  boot.supportedFilesystems.ntfs = true;

  environment.systemPackages = [ pkgs.efibootmgr ];

  security.allowSimultaneousMultithreading = false;
}
