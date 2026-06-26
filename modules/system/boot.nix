{ config, lib, pkgs, ... }:

let
  internalDisplayKernelParam = "video=eDP-1:d";

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

  badApplePlymouthTheme = pkgs.stdenvNoCC.mkDerivation {
    pname = "plymouth-theme-bad-apple";
    version = "2026-05-19";

    src = pkgs.fetchFromGitHub {
      owner = "ruanyouxing";
      repo = "bad-apple-plymouth";
      rev = "a82c7a16b9943021d6b7de097f7292c1b514c989";
      hash = "sha256-qvhnODlR3v0rYkOyec19e11Ju+8Fgskb07mVafgXRWo=";
    };

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      themeDir="$out/share/plymouth/themes/bad_apple"
      mkdir -p "$themeDir"
      cp -r ./* "$themeDir/"
      substituteInPlace "$themeDir/bad_apple.plymouth" \
        --replace-fail /usr/share/plymouth/themes/bad_apple "$themeDir"

      runHook postInstall
    '';

    meta = {
      description = "Bad Apple Plymouth boot splash";
      homepage = "https://github.com/ruanyouxing/bad-apple-plymouth";
      platforms = pkgs.lib.platforms.linux;
    };
  };

  fallbackKernelParams = builtins.filter (param: param != internalDisplayKernelParam) config.boot.kernelParams;
in
{
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    configurationLimit = 30;
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
    theme = "bad_apple";
    themePackages = [ badApplePlymouthTheme ];
  };
  boot.kernelParams = [
    "quiet"
    # Default to an external-only boot splash. GRUB still provides an
    # internal-display-fallback specialisation for boots without a monitor.
    internalDisplayKernelParam
    "udev.log_level=3"
  ];
  boot.supportedFilesystems.ntfs = true;

  specialisation.internal-display-fallback.configuration = {
    system.nixos.tags = [ "internal-display-fallback" ];
    boot.kernelParams = lib.mkForce fallbackKernelParams;
  };

  environment.systemPackages = [ pkgs.efibootmgr ];

  security.allowSimultaneousMultithreading = false;
}
