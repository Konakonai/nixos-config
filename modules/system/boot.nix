{ hostProfile, pkgs, ... }:

let
  touhouGrubTheme = pkgs.lilya.touhou-grub-theme;
  touhouPlymouthTheme = pkgs.lilya.touhou-plymouth-theme;
in
{
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    configurationLimit = 30;
    theme = touhouGrubTheme;
    splashImage = ../../assets/boot-background.png;
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

      # Keep a firmware-standard fallback alongside the NVRAM-managed entry so
      # a BIOS reset cannot strand the system without a bootable GRUB path.
      ${pkgs.coreutils}/bin/install -Dm755 \
        /boot/EFI/NixOS-boot/grubx64.efi \
        /boot/EFI/BOOT/BOOTX64.EFI
    '';
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "tun" ];
  boot.blacklistedKernelModules = hostProfile.kernel.blacklistedModules or [ ];
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.plymouth = {
    enable = true;
    theme = "touhou_logo";
    themePackages = [ touhouPlymouthTheme ];
  };
  boot.kernelParams = [
    "quiet"
    "udev.log_level=3"
    "rd.systemd.show_status=false"
    "systemd.show_status=false"
    # Prefer stable USB input latency over runtime power savings. Device-level
    # udev rules in power/device-rules.nix also enforce this after hotplug.
    "usbcore.autosuspend=-1"
    # tty1 is handed to Plymouth/kmscon; keep fbcon on fallback VTs so a
    # non-fullscreen kernel console is less likely to flash during handoff.
    "fbcon=vc:2-6"
    "vt.global_cursor_default=0"
  ];

  environment.systemPackages = [ pkgs.efibootmgr ];

  security.allowSimultaneousMultithreading = false;
}
