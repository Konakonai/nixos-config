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

    set_profile() {
      ${pkgs.coreutils}/bin/timeout 1s ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set "$1" 2>/dev/null || true
    }

    set_policy() {
      policy="$1"
      max_freq="$2"

      write_if_present "$policy/scaling_governor" powersave
      write_if_present "$policy/energy_performance_preference" power
      write_if_present "$policy/scaling_max_freq" "$max_freq"
    }

    battery_cpu() {
      set_profile power-saver

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
      set_profile balanced

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
in
{
  environment.systemPackages = [ cpuPowerSource ];

  systemd.services.cpu-power-source-boot = {
    description = "Apply CPU state based on AC power at boot";
    after = [ "local-fs.target" ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      ${cpuPowerSource}/bin/cpu-power-source auto
    '';
    serviceConfig = {
      Type = "oneshot";
      TimeoutSec = "5s";
    };
  };

  systemd.services.cpu-power-source-battery = {
    description = "Apply battery CPU limits when AC power is disconnected";
    script = ''
      ${cpuPowerSource}/bin/cpu-power-source battery
    '';
    serviceConfig = {
      Type = "oneshot";
      TimeoutSec = "5s";
    };
  };

  systemd.services.cpu-power-source-ac = {
    description = "Restore CPU performance when AC power is connected";
    script = ''
      ${cpuPowerSource}/bin/cpu-power-source ac
    '';
    serviceConfig = {
      Type = "oneshot";
      TimeoutSec = "5s";
    };
  };
}
