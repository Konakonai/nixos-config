{ ... }:

{
  systemd.services.battery-conservation-permissions = {
    description = "Set permissions for ThinkBook battery conservation mode and PCI rescan";
    after = [ "systemd-modules-load.service" ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      if [ -f /sys/bus/pci/rescan ]; then
        chown root:users /sys/bus/pci/rescan
        chmod 664 /sys/bus/pci/rescan
      fi

      # Set permissions for NVIDIA GPU controls when the dGPU is present.
      for dev in 0000:01:00.0 0000:01:00.1; do
        if [ -f /sys/bus/pci/devices/$dev/remove ]; then
          chown root:users /sys/bus/pci/devices/$dev/remove
          chmod 664 /sys/bus/pci/devices/$dev/remove
        fi

        if [ -f /sys/bus/pci/devices/$dev/power/control ]; then
          chown root:users /sys/bus/pci/devices/$dev/power/control
          chmod 664 /sys/bus/pci/devices/$dev/power/control
        fi
      done

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
}
