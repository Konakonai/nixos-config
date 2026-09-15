{ pkgs, ... }:

let
  pchReset = ../../scripts/reset-pch-usbc.sh;
  tbReset = ../../scripts/reset-tb-usbc.sh;
  resetPath = [
    pkgs.bash
    pkgs.coreutils
    pkgs.util-linux
  ];
in
{
  # The 10 Gbps Type-C port is PCH xHCI SS01 (usb4-port1) / HS02, UCSI port1.
  # The Thunderbolt Type-C port is USB4 xHCI 0000:00:0d.0 / UCSI port0.
  # PD sinks can leave either mux charging-only; bounce the matching xHCI
  # ports after a partner event. USB4 runtime PM also parks 00:0d.0, so keep
  # that controller on.
  services.hardware.bolt.enable = true;

  systemd.services.pch-usbc-reset = {
    description = "Recover PCH USB-C data after a Type-C PD event";
    path = resetPath;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${pchReset}";
    };
  };

  systemd.services.tb-usbc-reset = {
    description = "Recover Thunderbolt USB-C data after a Type-C PD event";
    path = resetPath;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash ${tbReset}";
    };
  };

  systemd.services.tb-usbc-prepare = {
    description = "Wake USB4 and clear idle Thunderbolt Type-C alt-modes";
    wantedBy = [ "multi-user.target" ];
    after = [ "sys-devices-platform-USBC000:00.device" ];
    path = resetPath;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash ${tbReset} prepare";
    };
  };

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:00:14.0", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:00:0d.0", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:00:0d.2", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:00:07.0", ATTR{power/control}="on"
    ACTION=="add|remove", SUBSYSTEM=="typec", KERNEL=="port1-partner", TAG+="systemd", ENV{SYSTEMD_WANTS}="pch-usbc-reset.service"
    ACTION=="add|remove", SUBSYSTEM=="typec", KERNEL=="port0-partner", TAG+="systemd", ENV{SYSTEMD_WANTS}="tb-usbc-reset.service"
  '';
}
