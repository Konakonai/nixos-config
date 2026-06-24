{ pkgs, ... }:

let
  nvidiaPowerSource = pkgs.writeShellScriptBin "nvidia-power-source" ''
    set -u

    ac_online() {
      [ "$(cat /sys/class/power_supply/ADP0/online 2>/dev/null || echo 0)" = "1" ]
    }

    set_profile() {
      ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set "$1" 2>/dev/null || true
    }

    nvidia_is_suspended() {
      [ "$(cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status 2>/dev/null || echo missing)" = "suspended" ]
    }

    remove_nvidia() {
      set_profile power-saver

      for dev in 0000:01:00.1 0000:01:00.0; do
        control="/sys/bus/pci/devices/$dev/power/control"
        [ -w "$control" ] && echo auto > "$control" 2>/dev/null || true
      done

      for _ in $(seq 1 20); do
        if nvidia_is_suspended; then
          break
        fi
        sleep 0.25
      done

      if ! nvidia_is_suspended; then
        echo "nvidia-power-source: NVIDIA did not runtime suspend; leaving PCI device present and relying on RTD3." >&2
        exit 0
      fi

      for dev in 0000:01:00.1 0000:01:00.0; do
        remove="/sys/bus/pci/devices/$dev/remove"
        [ -w "$remove" ] && echo 1 > "$remove" 2>/dev/null || true
      done
    }

    restore_nvidia() {
      set_profile balanced

      if [ -w /sys/bus/pci/rescan ]; then
        echo 1 > /sys/bus/pci/rescan 2>/dev/null || true
      fi

      for _ in $(seq 1 20); do
        control="/sys/bus/pci/devices/0000:01:00.0/power/control"
        if [ -w "$control" ]; then
          echo on > "$control" 2>/dev/null || true
          exit 0
        fi
        sleep 0.25
      done

      echo "nvidia-power-source: NVIDIA PCI device did not appear after rescan." >&2
    }

    case "''${1:-auto}" in
      auto)
        if ac_online; then
          restore_nvidia
        else
          remove_nvidia
        fi
        ;;
      battery|powersave)
        remove_nvidia
        ;;
      ac|performance)
        restore_nvidia
        ;;
      status)
        if ac_online; then
          echo "ac"
        else
          echo "battery"
        fi

        if [ -e /sys/bus/pci/devices/0000:01:00.0 ]; then
          echo "nvidia: present"
          cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status 2>/dev/null || true
          cat /sys/bus/pci/devices/0000:01:00.0/power/control 2>/dev/null || true
        else
          echo "nvidia: absent"
        fi
        ;;
      *)
        echo "usage: nvidia-power-source [auto|battery|ac|status]" >&2
        exit 2
        ;;
    esac
  '';
in
{
  environment.systemPackages = [ nvidiaPowerSource ];

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
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{device}=="0x28e0", RUN+="/bin/sh -c 'chown root:users /sys/bus/pci/devices/$kernel/remove /sys/bus/pci/devices/$kernel/power/control 2>/dev/null || true; chmod 664 /sys/bus/pci/devices/$kernel/remove /sys/bus/pci/devices/$kernel/power/control 2>/dev/null || true'"

    SUBSYSTEM=="power_supply", KERNEL=="ADP0", ATTR{online}=="0", RUN+="${pkgs.power-profiles-daemon}/bin/powerprofilesctl set power-saver"
    SUBSYSTEM=="power_supply", KERNEL=="ADP0", ATTR{online}=="1", RUN+="${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced"
    SUBSYSTEM=="power_supply", KERNEL=="ADP0", ATTR{online}=="1", TAG+="systemd", ENV{SYSTEMD_WANTS}+="nvidia-power-source-ac.service"
  '';

  systemd.services.nvidia-power-source-boot = {
    description = "Apply dGPU state based on AC power at boot";
    before = [
      "display-manager.service"
      "greetd.service"
    ];
    after = [
      "systemd-udev-settle.service"
      "local-fs.target"
    ];
    wants = [ "systemd-udev-settle.service" ];
    wantedBy = [ "graphical.target" ];
    script = ''
      ${nvidiaPowerSource}/bin/nvidia-power-source auto
    '';
    serviceConfig.Type = "oneshot";
  };

  systemd.services.nvidia-power-source-ac = {
    description = "Restore NVIDIA dGPU when AC power is connected";
    script = ''
      ${nvidiaPowerSource}/bin/nvidia-power-source ac
    '';
    serviceConfig.Type = "oneshot";
  };

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
