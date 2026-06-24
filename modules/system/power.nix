{ pkgs, ... }:

{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;

  powerManagement.powertop.enable = true;

  systemd.services.powertop.serviceConfig.ExecStartPost = pkgs.writeShellScript "disable-usb-autosuspend" ''
    for dev in /sys/bus/usb/devices/*; do
      if [ -d "$dev" ]; then
        if grep -q "03" "$dev"/*/bInterfaceClass 2>/dev/null; then
          echo "on" > "$dev/power/control" 2>/dev/null || true
        fi
      fi
    done
  '';

  services.udev.extraRules = ''
    # 当 NVIDIA 独显被添加（开机或重新扫描）时，自动赋予 users 用户组对 remove 文件的写入权限，以便普通用户可以直接一键关闭/移除独显而无需 sudo
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{device}=="0x28e0", RUN+="/bin/sh -c 'chown root:users /sys/bus/pci/devices/$kernel/remove && chmod 664 /sys/bus/pci/devices/$kernel/remove'"

    SUBSYSTEM=="power_supply", KERNEL=="ADP0", ATTR{online}=="0", RUN+="${pkgs.power-profiles-daemon}/bin/powerprofilesctl set power-saver"
    SUBSYSTEM=="power_supply", KERNEL=="ADP0", ATTR{online}=="1", RUN+="${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced"
  '';

  systemd.services.battery-conservation-permissions = {
    description = "Set permissions for ThinkBook battery conservation mode and PCI rescan";
    after = [ "systemd-modules-load.service" ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      if [ -f /sys/bus/pci/rescan ]; then
        chown root:users /sys/bus/pci/rescan
        chmod 664 /sys/bus/pci/rescan
      fi

      # Set permissions for Nvidia GPU power control and enable GPU power auto-suspend (enable RTD3)
      if [ -f /sys/bus/pci/devices/0000:01:00.0/power/control ]; then
        chown root:users /sys/bus/pci/devices/0000:01:00.0/power/control
        chmod 664 /sys/bus/pci/devices/0000:01:00.0/power/control
        echo "auto" > /sys/bus/pci/devices/0000:01:00.0/power/control
      fi

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
