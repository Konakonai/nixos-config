{
  hostProfile,
  lib,
  pkgs,
  ...
}:

let
  nvidia = hostProfile.graphics.nvidia or { enable = false; };
  pci = nvidia.pci;
  hexByte = value: lib.fixedWidthString 2 "0" (lib.toLower (lib.toHexString value));
  pciAddress = "0000:${hexByte pci.bus}:${hexByte pci.device}.${toString pci.function}";

  # Waking the dGPU from runtime D3 takes ~1.5 s and whatever touched it blocks
  # for that long (see Smithay/smithay#2178 for the compositor case). On mains
  # the saved power is not worth those stalls, so keep the GPU awake there and
  # only let it sleep on battery. Runs after the fine-grained rules from the
  # NixOS nvidia module because RUN programs execute once all rules are done.
  applyPolicy = pkgs.writeShellScript "dgpu-runtime-pm" ''
    set -eu
    control=/sys/bus/pci/devices/${pciAddress}/power/control
    [ -w "$control" ] || exit 0
    online=0
    read -r online < /sys/class/power_supply/ADP0/online || true
    if [ "$online" = 1 ]; then
      echo on > "$control"
    else
      echo auto > "$control"
    fi
  '';
in
lib.mkIf (nvidia.enable or false) {
  services.udev.extraRules = ''
    ACTION=="bind", SUBSYSTEM=="pci", KERNEL=="${pciAddress}", RUN+="${applyPolicy}"
    ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="ADP0", RUN+="${applyPolicy}"
  '';
}
