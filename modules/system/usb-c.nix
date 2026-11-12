{ pkgs, ... }:

let
  reset = "${pkgs.bash}/bin/bash ${../../scripts/reset-usbc.sh}";
  resetPath = [
    pkgs.bash
    pkgs.coreutils
    pkgs.util-linux
  ];
in
{
  # The 10 Gbps Type-C port is PCH xHCI SS01 (usb4-port1) / HS02, UCSI port1.
  # The Thunderbolt Type-C port is USB4 xHCI 0000:00:0d.0 SuperSpeed plus PCH
  # HS01 USB2 (Intel USB4: USB2 is sourced from the PCH). UCSI port0.
  # Native USB-C devices on that port often never appear as a typec partner
  # (UCSI stays UFP with no partner sysfs); USB2 still enumerates on HS01.
  # PD sinks can leave either mux charging-only; bounce the matching xHCI
  # ports after a partner, connector-change, or HS01 unplug. USB4 runtime PM
  # also parks 00:0d.0, so keep that controller on.
  #
  # Measured on battery with both ports empty (2026-11-12, interleaved
  # rounds): the watch service costs about 0.2 W, so it runs on mains only.
  # Leaving the four controllers on `auto` instead of pinned saves nothing
  # measurable: 00:14.0 stays runtime-active on `auto` anyway, and package
  # C8/C10 stay at 0 either way because the panel has no PSR. So the pins
  # stay, including 00:14.0, whose original reason was never recorded.
  services.hardware.bolt.enable = true;

  # With the watch service off on battery, a device that raises no udev event
  # at all needs the recovery started by hand.
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "usbc-recover" ''
      exec /run/wrappers/bin/sudo ${pkgs.systemd}/bin/systemctl start \
        tb-usbc-reset.service pch-usbc-reset.service
    '')
  ];

  systemd.services.pch-usbc-reset = {
    description = "Recover PCH USB-C data after a Type-C PD event";
    path = resetPath;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${reset} pch";
    };
  };

  systemd.services.tb-usbc-reset = {
    description = "Recover Thunderbolt USB-C data after a Type-C PD event";
    path = resetPath;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${reset} tb";
    };
  };

  systemd.services.tb-usbc-rearm = {
    description = "Rearm Thunderbolt USB2 (PCH HS01) after unplug";
    path = resetPath;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${reset} tb rearm";
    };
  };

  systemd.services.tb-usbc-watch = {
    description = "Poll-bounce Thunderbolt USB2 when UCSI omits the partner";
    wantedBy = [ "multi-user.target" ];
    after = [ "tb-usbc-prepare.service" ];
    # The condition covers boot and rebuilds; the udev rules below start and
    # stop it when the charger is plugged or pulled.
    unitConfig.ConditionACPower = true;
    path = resetPath;
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "2s";
      ExecStart = "${reset} tb watch";
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
      ExecStart = "${reset} tb prepare";
    };
  };

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:00:14.0", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:00:0d.0", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:00:0d.2", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:00:07.0", ATTR{power/control}="on"
    ACTION=="add|remove", SUBSYSTEM=="typec", KERNEL=="port1-partner", TAG+="systemd", ENV{SYSTEMD_WANTS}="pch-usbc-reset.service"
    ACTION=="add|remove", SUBSYSTEM=="typec", KERNEL=="port0-partner", TAG+="systemd", ENV{SYSTEMD_WANTS}="tb-usbc-reset.service"
    ACTION=="change", SUBSYSTEM=="typec", KERNEL=="port0", TAG+="systemd", ENV{SYSTEMD_WANTS}="tb-usbc-reset.service"
    ACTION=="remove", SUBSYSTEM=="usb", KERNEL=="3-1", TAG+="systemd", ENV{SYSTEMD_WANTS}="tb-usbc-rearm.service"
    ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="ADP0", ATTR{online}=="1", RUN+="${pkgs.systemd}/bin/systemctl start --no-block tb-usbc-watch.service"
    ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="ADP0", ATTR{online}=="0", RUN+="${pkgs.systemd}/bin/systemctl stop --no-block tb-usbc-watch.service"
  '';
}
