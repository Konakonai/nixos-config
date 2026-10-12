{
  hostProfile,
  lib,
  pkgs,
  ...
}:

let
  inherit (hostProfile.graphics.nvidia) pci;
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
{
  # udev re-evaluates on driver bind and AC plug/unplug; the oneshot applies
  # the policy at boot and on every rebuild, when no such event is replayed.
  services.udev.extraRules = ''
    ACTION=="bind", SUBSYSTEM=="pci", KERNEL=="${pciAddress}", RUN+="${applyPolicy}"
    ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="ADP0", RUN+="${applyPolicy}"
  '';

  systemd.services.dgpu-runtime-pm = {
    description = "Keep the NVIDIA dGPU awake on mains";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = applyPolicy;
    };
  };
}
