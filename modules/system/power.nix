{ pkgs, ... }:

let
  cpuPowerSource = pkgs.writeShellScriptBin "cpu-power-source" ''
    set -u

    ac_online() {
      [ "$(cat /sys/class/power_supply/ADP0/online 2>/dev/null || echo 0)" = "1" ]
    }

    write_if_present() {
      path="$1"
      value="$2"
      [ -w "$path" ] && echo "$value" > "$path" 2>/dev/null || true
    }

    set_policy() {
      policy="$1"
      max_freq="$2"

      write_if_present "$policy/scaling_governor" powersave
      write_if_present "$policy/energy_performance_preference" power
      write_if_present "$policy/scaling_max_freq" "$max_freq"
    }

    battery_cpu() {
      ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set power-saver 2>/dev/null || true

      write_if_present /sys/devices/system/cpu/intel_pstate/no_turbo 1
      write_if_present /sys/devices/system/cpu/smt/control off

      # Keep two P-core primary threads plus all eight E-cores online.
      for cpu in 4 6 8 10; do
        write_if_present "/sys/devices/system/cpu/cpu$cpu/online" 0
      done

      for cpu in 12 13 14 15 16 17 18 19; do
        write_if_present "/sys/devices/system/cpu/cpu$cpu/online" 1
      done

      for policy in /sys/devices/system/cpu/cpufreq/policy*; do
        [ -d "$policy" ] || continue
        cpu="''${policy##*policy}"

        if [ "$cpu" -ge 12 ] 2>/dev/null; then
          set_policy "$policy" 2200000
        else
          set_policy "$policy" 1800000
        fi
      done
    }

    ac_cpu() {
      ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced 2>/dev/null || true

      write_if_present /sys/devices/system/cpu/smt/control on

      for cpu_path in /sys/devices/system/cpu/cpu[1-9]*; do
        [ -e "$cpu_path/online" ] || continue
        write_if_present "$cpu_path/online" 1
      done

      write_if_present /sys/devices/system/cpu/intel_pstate/no_turbo 0

      for policy in /sys/devices/system/cpu/cpufreq/policy*; do
        [ -d "$policy" ] || continue
        max="$(cat "$policy/cpuinfo_max_freq" 2>/dev/null || true)"
        [ -n "$max" ] && write_if_present "$policy/scaling_max_freq" "$max"
        write_if_present "$policy/energy_performance_preference" balance_performance
        write_if_present "$policy/scaling_governor" powersave
      done
    }

    status_cpu() {
      if ac_online; then
        echo "ac"
      else
        echo "battery"
      fi

      printf "smt: "
      cat /sys/devices/system/cpu/smt/control 2>/dev/null || true
      printf "turbo_disabled: "
      cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
      printf "online: "
      cat /sys/devices/system/cpu/online 2>/dev/null || true

      for policy in /sys/devices/system/cpu/cpufreq/policy0 /sys/devices/system/cpu/cpufreq/policy12; do
        [ -d "$policy" ] || continue
        echo "$(basename "$policy"): max=$(cat "$policy/scaling_max_freq" 2>/dev/null) epp=$(cat "$policy/energy_performance_preference" 2>/dev/null)"
      done
    }

    case "''${1:-auto}" in
      auto)
        if ac_online; then
          ac_cpu
        else
          battery_cpu
        fi
        ;;
      battery|powersave)
        battery_cpu
        ;;
      ac|performance)
        ac_cpu
        ;;
      status)
        status_cpu
        ;;
      *)
        echo "usage: cpu-power-source [auto|battery|ac|status]" >&2
        exit 2
        ;;
    esac
  '';

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

    nvidia_is_present() {
      [ -e /sys/bus/pci/devices/0000:01:00.0 ]
    }

    typec_display_connected() {
      for partner in /sys/class/typec/port*-partner; do
        [ -e "$partner" ] || continue

        # DisplayPort alt-mode uses VESA SVID 0xff01. Prefer that signal when
        # the Type-C partner exposes alt modes, but fall back to partner
        # presence because this machine uses Type-C ports for external display.
        for svid in "$partner"/*/svid; do
          [ -e "$svid" ] || continue
          if [ "$(cat "$svid" 2>/dev/null || true)" = "0xff01" ]; then
            return 0
          fi
        done

        for description in "$partner"/*/description; do
          [ -e "$description" ] || continue
          if grep -qi "displayport\\|display port\\|dp" "$description" 2>/dev/null; then
            return 0
          fi
        done

        if [ -d "$partner" ]; then
          return 0
        fi
      done

      return 1
    }

    rescan_missing_nvidia() {
      if nvidia_is_present; then
        return 0
      fi

      if [ -w /sys/bus/pci/rescan ]; then
        echo 1 > /sys/bus/pci/rescan 2>/dev/null || true
      fi

      for _ in $(seq 1 20); do
        if nvidia_is_present; then
          return 0
        fi
        sleep 0.25
      done

      echo "nvidia-power-source: NVIDIA PCI device did not appear after rescan." >&2
      return 1
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

      rescan_missing_nvidia
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

        if typec_display_connected; then
          echo "typec-display: connected"
        else
          echo "typec-display: disconnected"
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
  environment.systemPackages = [
    cpuPowerSource
    nvidiaPowerSource
  ];

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
    SUBSYSTEM=="power_supply", KERNEL=="ADP0", ATTR{online}=="0", TAG+="systemd", ENV{SYSTEMD_WANTS}+="cpu-power-source-battery.service nvidia-power-source-battery.service"
    SUBSYSTEM=="power_supply", KERNEL=="ADP0", ATTR{online}=="1", RUN+="${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced"
    SUBSYSTEM=="power_supply", KERNEL=="ADP0", ATTR{online}=="1", TAG+="systemd", ENV{SYSTEMD_WANTS}+="cpu-power-source-ac.service nvidia-power-source-ac.service"
  '';

  systemd.services.cpu-power-source-boot = {
    description = "Apply CPU state based on AC power at boot";
    after = [
      "systemd-udev-settle.service"
      "local-fs.target"
    ];
    wants = [ "systemd-udev-settle.service" ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      ${cpuPowerSource}/bin/cpu-power-source auto
    '';
    serviceConfig.Type = "oneshot";
  };

  systemd.services.cpu-power-source-battery = {
    description = "Apply battery CPU limits when AC power is disconnected";
    script = ''
      ${cpuPowerSource}/bin/cpu-power-source battery
    '';
    serviceConfig.Type = "oneshot";
  };

  systemd.services.cpu-power-source-ac = {
    description = "Restore CPU performance when AC power is connected";
    script = ''
      ${cpuPowerSource}/bin/cpu-power-source ac
    '';
    serviceConfig.Type = "oneshot";
  };

  systemd.services.nvidia-power-source-boot = {
    description = "Apply dGPU state based on AC power at boot";
    after = [ "local-fs.target" ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      ${nvidiaPowerSource}/bin/nvidia-power-source auto
    '';
    serviceConfig.Type = "oneshot";
  };

  systemd.services.nvidia-power-source-battery = {
    description = "Power down NVIDIA dGPU when AC power is disconnected";
    script = ''
      ${nvidiaPowerSource}/bin/nvidia-power-source battery
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
