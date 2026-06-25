{ ... }:

{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;

  powerManagement.powertop.enable = true;

  systemd.services.battery-conservation-permissions = {
    description = "Set permissions for ThinkBook battery conservation mode";
    after = [ "systemd-modules-load.service" ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      for i in $(seq 1 15); do
        if [ -f /sys/class/power_supply/BAT0/extensions/ideapad_laptop/conservation_mode ]; then
          chown lilya:users /sys/class/power_supply/BAT0/extensions/ideapad_laptop/conservation_mode
          chmod 664 /sys/class/power_supply/BAT0/extensions/ideapad_laptop/conservation_mode
          exit 0
        fi
        sleep 1
      done
    '';
    serviceConfig.Type = "oneshot";
  };

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", RUN+="/bin/sh -c 'chown root:users /sys/bus/pci/devices/$kernel/power/control 2>/dev/null || true; chmod 664 /sys/bus/pci/devices/$kernel/power/control 2>/dev/null || true'"
  '';

  systemd.services.nvidia-power-control-permissions = {
    description = "Allow users group to adjust NVIDIA runtime power control";
    after = [ "systemd-udevd.service" ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      for dev in 0000:01:00.1 0000:01:00.0; do
        control="/sys/bus/pci/devices/$dev/power/control"
        if [ -f "$control" ]; then
          chown root:users "$control"
          chmod 664 "$control"
        fi
      done
    '';
    serviceConfig.Type = "oneshot";
  };
}
