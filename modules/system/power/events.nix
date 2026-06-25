{ pkgs, ... }:

{
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="ADP0", ATTR{online}=="0", TAG+="systemd", ENV{SYSTEMD_WANTS}+="cpu-power-source-battery.service nvidia-power-source-battery.service"
    SUBSYSTEM=="power_supply", KERNEL=="ADP0", ATTR{online}=="1", TAG+="systemd", ENV{SYSTEMD_WANTS}+="cpu-power-source-ac.service nvidia-power-source-ac.service"
  '';
}
