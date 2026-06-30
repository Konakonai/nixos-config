{ config, hostProfile, lib, pkgs, ... }:

let
  power = hostProfile.power or { };
  batteryConservationPath = power.batteryConservationPath or null;
  keepAwakeUsbDevices = power.keepAwakeUsbDevices or [ ];
  nvidiaKernelModules = [
    "nouveau"
    "nvidia"
    "nvidia_drm"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidiafb"
  ];
  chargeLimit = pkgs.writeShellScriptBin "charge-limit" ''
    set -eu

    LIMIT_PATH="${batteryConservationPath}"

    if [ "$#" -ne 0 ]; then
      echo "usage: charge-limit" >&2
      exit 1
    fi

    if [ ! -e "$LIMIT_PATH" ]; then
      echo "charge limit control not found: $LIMIT_PATH" >&2
      exit 1
    fi

    if [ ! -w "$LIMIT_PATH" ]; then
      echo "charge limit control is not writable: $LIMIT_PATH" >&2
      exit 1
    fi

    notify() {
      ${pkgs.libnotify}/bin/notify-send \
        --app-name=charge-limit \
        "Charge limit" \
        "Now charging up to $1" >/dev/null 2>&1 || true
    }

    case "$(${pkgs.coreutils}/bin/cat "$LIMIT_PATH")" in
      1)
        echo 0 > "$LIMIT_PATH"
        echo "100%"
        notify "100%"
        ;;
      0)
        echo 1 > "$LIMIT_PATH"
        echo "80%"
        notify "80%"
        ;;
      *)
        echo "cannot toggle unknown charge limit state" >&2
        exit 1
        ;;
    esac
  '';
  batterySaver = pkgs.writeShellScriptBin "battery-saver" ''
    set -eu

    RAPL_LONG_UW=8000000
    RAPL_SHORT_UW=12000000
    CPU_MAX_PERF_PCT=35
    PERFORMANCE_CPU_KEEP=2
    EFFICIENT_CPU_KEEP=4

    write_sysfs() {
      path="$1"
      value="$2"

      if [ ! -e "$path" ]; then
        return 0
      fi

      if [ ! -w "$path" ]; then
        echo "skip $path: not writable" >&2
        return 0
      fi

      printf '%s\n' "$value" > "$path" 2>/dev/null || {
        echo "skip $path: write failed" >&2
        return 0
      }

      echo "$path=$value"
    }

    show_sysfs() {
      label="$1"
      path="$2"

      if [ -e "$path" ]; then
        printf '%s: ' "$label"
        cat "$path" 2>/dev/null || true
      fi
    }

    apply_platform_profile() {
      if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set power-saver >/dev/null 2>&1 || true
      fi

      write_sysfs /sys/firmware/acpi/platform_profile low-power
    }

    apply_cpu_limits() {
      write_sysfs /sys/devices/system/cpu/intel_pstate/no_turbo 1
      write_sysfs /sys/devices/system/cpu/intel_pstate/max_perf_pct "$CPU_MAX_PERF_PCT"

      for policy in /sys/devices/system/cpu/cpufreq/policy*; do
        [ -d "$policy" ] || continue
        write_sysfs "$policy/scaling_governor" powersave
        write_sysfs "$policy/energy_performance_preference" power
      done
    }

    apply_cpu_core_limits() {
      max_freq=0
      for cpu_path in $(printf '%s\n' /sys/devices/system/cpu/cpu[0-9]* | sort -V); do
        [ -d "$cpu_path" ] || continue
        freq="$(cat "$cpu_path/cpufreq/cpuinfo_max_freq" 2>/dev/null || echo 0)"
        case "$freq" in
          ""|*[!0-9]*)
            continue
            ;;
        esac

        if [ "$freq" -gt "$max_freq" ]; then
          max_freq="$freq"
        fi
      done

      if [ "$max_freq" -le 0 ]; then
        echo "skip cpu hotplug: cannot classify CPU core types" >&2
        return 0
      fi

      performance_threshold="$((max_freq * 85 / 100))"
      performance_seen=0
      efficient_seen=0

      for cpu_path in $(printf '%s\n' /sys/devices/system/cpu/cpu[0-9]* | sort -V); do
        [ -d "$cpu_path" ] || continue
        cpu="''${cpu_path##*/cpu}"
        freq="$(cat "$cpu_path/cpufreq/cpuinfo_max_freq" 2>/dev/null || echo 0)"

        case "$cpu:$freq" in
          *[!0-9:]*|:*|*:)
            continue
            ;;
        esac

        if [ "$freq" -ge "$performance_threshold" ]; then
          performance_seen="$((performance_seen + 1))"
          if [ "$performance_seen" -le "$PERFORMANCE_CPU_KEEP" ]; then
            write_sysfs "$cpu_path/online" 1
          else
            write_sysfs "$cpu_path/online" 0
          fi
        else
          efficient_seen="$((efficient_seen + 1))"
          if [ "$efficient_seen" -le "$EFFICIENT_CPU_KEEP" ]; then
            write_sysfs "$cpu_path/online" 1
          else
            write_sysfs "$cpu_path/online" 0
          fi
        fi
      done
    }

    apply_rapl_limits() {
      for zone in /sys/devices/virtual/powercap/intel-rapl*/intel-rapl*:0; do
        [ -d "$zone" ] || continue

        for name_path in "$zone"/constraint_*_name; do
          [ -e "$name_path" ] || continue
          limit_path="''${name_path%_name}_power_limit_uw"

          case "$(cat "$name_path" 2>/dev/null || true)" in
            long_term)
              write_sysfs "$limit_path" "$RAPL_LONG_UW"
              ;;
            short_term)
              write_sysfs "$limit_path" "$RAPL_SHORT_UW"
              ;;
          esac
        done
      done
    }

    apply_device_savings() {
      for device in /sys/bus/pci/devices/*; do
        [ -d "$device" ] || continue
        write_sysfs "$device/power/control" auto
      done

      write_sysfs /sys/module/snd_hda_intel/parameters/power_save 1
      write_sysfs /sys/module/snd_hda_intel/parameters/power_save_controller Y

      if command -v iw >/dev/null 2>&1; then
        for iface in /sys/class/net/*; do
          [ -d "$iface/wireless" ] || continue
          iw dev "''${iface##*/}" set power_save on >/dev/null 2>&1 || true
        done
      fi
    }

    status() {
      if command -v powerprofilesctl >/dev/null 2>&1; then
        printf 'power profile: '
        powerprofilesctl get 2>/dev/null || true
      fi

      show_sysfs "platform profile" /sys/firmware/acpi/platform_profile
      show_sysfs "intel_pstate no_turbo" /sys/devices/system/cpu/intel_pstate/no_turbo
      show_sysfs "intel_pstate max_perf_pct" /sys/devices/system/cpu/intel_pstate/max_perf_pct
      printf 'online cpus: '
      cat /sys/devices/system/cpu/online 2>/dev/null || true

      for zone in /sys/devices/virtual/powercap/intel-rapl*/intel-rapl*:0; do
        [ -d "$zone" ] || continue
        show_sysfs "$(basename "$zone") long term" "$zone/constraint_0_power_limit_uw"
        show_sysfs "$(basename "$zone") short term" "$zone/constraint_1_power_limit_uw"
      done

      if [ -r /proc/modules ]; then
        printf 'nvidia modules: '
        if grep -q '^nvidia' /proc/modules; then
          grep '^nvidia' /proc/modules | cut -d' ' -f1 | tr '\n' ' '
          printf '\n'
        else
          echo none
        fi
      fi
    }

    case "''${1:-apply}" in
      apply)
        apply_platform_profile
        apply_cpu_limits
        apply_cpu_core_limits
        apply_rapl_limits
        apply_device_savings
        ;;
      status)
        status
        ;;
      *)
        echo "usage: $0 [apply|status]" >&2
        exit 1
        ;;
    esac
  '';
in
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;

  powerManagement.powertop.enable = false;

  environment.systemPackages =
    lib.optional (batteryConservationPath != null) chargeLimit;

  services.udev.extraRules = lib.concatStringsSep "\n" (
    # Keep latency-sensitive HID devices awake. PowerTOP auto-tuning was putting
    # these behind USB autosuspend, which matched the observed mouse/keyboard stalls.
    map (device:
      ''ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="${device.vendor}", ATTR{idProduct}=="${device.product}", TEST=="power/control", ATTR{power/control}="on"''
    ) keepAwakeUsbDevices
  );

  systemd.services = lib.optionalAttrs (batteryConservationPath != null) {
    battery-conservation-permissions = {
      description = "Set permissions for battery conservation mode";
      after = [ "systemd-modules-load.service" ];
      wantedBy = [ "multi-user.target" ];
      script = ''
        for i in $(seq 1 15); do
          if [ -f ${batteryConservationPath} ]; then
            chown ${hostProfile.user.userName}:${hostProfile.user.group} ${batteryConservationPath}
            chmod 664 ${batteryConservationPath}
            exit 0
          fi
          sleep 1
        done
      '';
      serviceConfig.Type = "oneshot";
    };
  };

  specialisation.battery-saver.configuration = {
    system.nixos.tags = [ "battery-saver" ];
    system.nixos.label = "battery-saver";
    boot.initrd.kernelModules = lib.mkForce (
      builtins.filter (module: !(builtins.elem module nvidiaKernelModules)) config.boot.initrd.kernelModules
    );
    boot.blacklistedKernelModules = lib.mkAfter nvidiaKernelModules;
    boot.extraModprobeConfig = lib.mkAfter ''
      blacklist nouveau
      blacklist nvidia
      blacklist nvidia_drm
      blacklist nvidia_modeset
      blacklist nvidia_uvm
      blacklist nvidiafb
      options nouveau modeset=0
    '';
    boot.kernelParams = lib.mkAfter [
      "i915.enable_fbc=1"
      "i915.enable_psr=1"
      "module_blacklist=${lib.concatStringsSep "," nvidiaKernelModules}"
      "pcie_aspm.policy=powersupersave"
    ];
    services.xserver.videoDrivers = lib.mkForce [ "modesetting" ];
    hardware.nvidia.modesetting.enable = lib.mkForce false;
    hardware.nvidia.nvidiaSettings = lib.mkForce false;
    hardware.nvidia.powerManagement.enable = lib.mkForce false;
    hardware.nvidia.powerManagement.finegrained = lib.mkForce false;
    hardware.nvidia.prime.offload.enable = lib.mkForce false;
    hardware.nvidia.prime.offload.enableOffloadCmd = lib.mkForce false;
    powerManagement.cpuFreqGovernor = lib.mkForce "powersave";
    environment.systemPackages = [ batterySaver ];

    systemd.services.battery-saver = {
      description = "Apply battery saver settings";
      after = [
        "multi-user.target"
        "power-profiles-daemon.service"
        "thermald.service"
      ];
      wants = [
        "power-profiles-daemon.service"
        "thermald.service"
      ];
      wantedBy = [ "graphical.target" ];
      path = [
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.gnused
        pkgs.iw
        pkgs.power-profiles-daemon
      ];
      script = "${batterySaver}/bin/battery-saver apply";
      serviceConfig.Type = "oneshot";
    };
  };
}
