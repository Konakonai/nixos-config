{ pkgs, ... }:

let
  resetScript = ../../scripts/reset-pch-usbc.sh;
in
{
  # The 10 Gbps Type-C port is PCH xHCI SS01 (usb4-port1) with USB2 companion
  # HS02 (usb3-port2). UCSI port1 is that connector. PD sinks can leave the mux
  # charging-only; bounce those two ports after a partner appears or leaves.
  systemd.services.pch-usbc-reset = {
    description = "Recover PCH USB-C data after a Type-C PD event";
    path = [
      pkgs.bash
      pkgs.coreutils
      pkgs.util-linux
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${resetScript}";
    };
  };

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:00:14.0", ATTR{power/control}="on"
    ACTION=="add|remove", SUBSYSTEM=="typec", KERNEL=="port1-partner", TAG+="systemd", ENV{SYSTEMD_WANTS}="pch-usbc-reset.service"
  '';
}
