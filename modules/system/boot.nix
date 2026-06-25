{ pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 30;
  boot.loader.systemd-boot.extraInstallCommands = ''
    linuxBootId="$(
      ${pkgs.efibootmgr}/bin/efibootmgr \
        | ${pkgs.gawk}/bin/awk '/Linux Boot Manager/ { id = $1; sub(/^Boot/, "", id); sub(/\*.*/, "", id); print id; exit }'
    )"

    if [ -n "$linuxBootId" ]; then
      currentOrder="$(${pkgs.efibootmgr}/bin/efibootmgr | ${pkgs.gnused}/bin/sed -n 's/^BootOrder: //p')"
      restOrder="$(
        printf '%s\n' "$currentOrder" \
          | ${pkgs.gnused}/bin/sed \
              -e "s/^$linuxBootId,//" \
              -e "s/,$linuxBootId,/,/" \
              -e "s/,$linuxBootId$//" \
              -e "s/^$linuxBootId$//"
      )"

      if [ -n "$restOrder" ]; then
        desiredOrder="$linuxBootId,$restOrder"
      else
        desiredOrder="$linuxBootId"
      fi

      if [ -n "$currentOrder" ] && [ "$currentOrder" != "$desiredOrder" ]; then
        ${pkgs.efibootmgr}/bin/efibootmgr -o "$desiredOrder"
      fi
    fi
  '';
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "tun" ];
  boot.kernelParams = [ "nvidia-drm.modeset=1" "nvidia-drm.fbdev=1" "i915.enable_guc=3" ];
  boot.supportedFilesystems.ntfs = true;

  environment.systemPackages = [ pkgs.efibootmgr ];

  security.allowSimultaneousMultithreading = false;
}
