{ pkgs, ... }:

let
  touhouGrubTheme = pkgs.lilya.touhou-grub-theme;
in
{
  boot.loader = {
    systemd-boot.enable = false;
    efi.canTouchEfiVariables = true;

    grub = {
      enable = true;
      efiSupport = true;
      configurationLimit = 30;
      theme = touhouGrubTheme;
      splashImage = ../../../assets/boot-background.png;

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

      # NixOS cannot combine efiInstallAsRemovable with a managed NVRAM entry.
      # Keep the normal NVRAM path and copy the resulting binary to the
      # firmware-standard fallback location after every GRUB installation.
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

        ${pkgs.coreutils}/bin/install -Dm755 \
          /boot/EFI/NixOS-boot/grubx64.efi \
          /boot/EFI/BOOT/BOOTX64.EFI
      '';
    };
  };

  environment.systemPackages = [ pkgs.efibootmgr ];
}
