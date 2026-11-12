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
  # only let it sleep on battery. "Mains" is any non-battery supply: ADP0 lags
  # a Type-C PD contract by about 5 s (measured 2026-11-13), and waking from
  # D3 in that gap stalls the compositor. Runs after the fine-grained rules
  # from the NixOS nvidia module because RUN programs execute once all rules
  # are done.
  onExternalPower = "${pkgs.bash}/bin/bash ${../../../scripts/external-power.sh}";
  applyPolicy = pkgs.writeShellScript "dgpu-runtime-pm" ''
    set -eu
    control=/sys/bus/pci/devices/${pciAddress}/power/control
    [ -w "$control" ] || exit 0
    if ${onExternalPower}; then
      echo on > "$control"
    else
      echo auto > "$control"
    fi
  '';
in
{
  # udev re-evaluates on driver bind and on any external-supply change; the
  # oneshot applies the policy at boot and on every rebuild, when no such
  # event is replayed.
  services.udev.extraRules = ''
    ACTION=="bind", SUBSYSTEM=="pci", KERNEL=="${pciAddress}", RUN+="${applyPolicy}"
    ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="ADP0", RUN+="${applyPolicy}"
    ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="ucsi-source-psy-*", RUN+="${applyPolicy}"
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
