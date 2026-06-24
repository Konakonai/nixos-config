{ lib, pkgs, ... }:

let
  configDir = "/home/lilya/nixos-config";
  configurationFile = "${configDir}/configuration.nix";
  moduleFile = "${configDir}/modules/system/disable-nvidia-once.nix";
  flakeRef = "${configDir}#nixos";

  cleanupScript = pkgs.writeShellScript "cleanup-disable-nvidia-once" ''
    set -u

    tmp="$(${pkgs.coreutils}/bin/mktemp)"
    ${pkgs.gawk}/bin/awk '
      $0 == "    # TEMP: disable-nvidia-once" { skip = 1; next }
      skip && $0 == "    ./modules/system/disable-nvidia-once.nix" { skip = 0; next }
      { print }
    ' ${lib.escapeShellArg configurationFile} > "$tmp"

    if ! ${pkgs.diffutils}/bin/cmp -s "$tmp" ${lib.escapeShellArg configurationFile}; then
      ${pkgs.coreutils}/bin/install -m 0644 "$tmp" ${lib.escapeShellArg configurationFile}
    fi

    ${pkgs.coreutils}/bin/rm -f "$tmp" ${lib.escapeShellArg moduleFile}

    if [ -d ${lib.escapeShellArg "${configDir}/.git"} ]; then
      ${pkgs.git}/bin/git -C ${lib.escapeShellArg configDir} reset -q -- \
        configuration.nix \
        modules/system/disable-nvidia-once.nix || true
    fi
  '';

  bootOnlyCondition = pkgs.writeShellScript "disable-nvidia-once-boot-only-condition" ''
    booted="$(${pkgs.coreutils}/bin/readlink -f /run/booted-system 2>/dev/null || true)"
    current="$(${pkgs.coreutils}/bin/readlink -f /run/current-system 2>/dev/null || true)"

    [ -n "$booted" ] && [ "$booted" = "$current" ]
  '';
in
{
  services.xserver.videoDrivers = lib.mkForce [ "modesetting" ];

  hardware.nvidia = {
    modesetting.enable = lib.mkForce false;
    nvidiaSettings = lib.mkForce false;
    powerManagement.enable = lib.mkForce false;
    powerManagement.finegrained = lib.mkForce false;
    prime.offload.enable = lib.mkForce false;
    prime.offload.enableOffloadCmd = lib.mkForce false;
  };

  boot.blacklistedKernelModules = [
    "nvidia"
    "nvidia_drm"
    "nvidia_modeset"
    "nvidia_uvm"
    "nouveau"
  ];

  boot.kernelParams = [
    "module_blacklist=nvidia,nvidia_drm,nvidia_modeset,nvidia_uvm,nouveau"
    "modprobe.blacklist=nvidia,nvidia_drm,nvidia_modeset,nvidia_uvm,nouveau"
  ];

  systemd.services.disable-nvidia-once = {
    description = "Disable the NVIDIA dGPU for this boot and remove the temporary config";
    before = [
      "display-manager.service"
      "greetd.service"
    ];
    after = [
      "systemd-udev-settle.service"
      "local-fs.target"
    ];
    wants = [ "systemd-udev-settle.service" ];
    wantedBy = [ "graphical.target" ];

    script = ''
      set -u

      for dev in 0000:01:00.1 0000:01:00.0; do
        remove="/sys/bus/pci/devices/$dev/remove"
        if [ -w "$remove" ]; then
          echo 1 > "$remove" || true
        fi
      done

      ${cleanupScript}

      ${pkgs.systemd}/bin/systemd-run \
        --unit=nixos-rebuild-after-disable-nvidia-once \
        --description="Restore normal NixOS boot config after one-shot NVIDIA disable" \
        --on-active=2min \
        ${pkgs.nixos-rebuild}/bin/nixos-rebuild boot --flake ${lib.escapeShellArg flakeRef} || true
    '';

    serviceConfig = {
      Type = "oneshot";
      ExecCondition = "${bootOnlyCondition}";
      RemainAfterExit = true;
    };
  };
}
