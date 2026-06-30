{ hostProfile, lib, pkgs, ... }:

let
  nvidia = hostProfile.graphics.nvidia or { enable = false; };
  power = hostProfile.power or { };
  batteryConservationPath = power.batteryConservationPath or null;
  keepAwakeUsbDevices = power.keepAwakeUsbDevices or [ ];
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
  nvidiaPowerControl = pkgs.writeShellScriptBin "nvidia-power-control" ''
    set -eu

    GPU_CONTROL="/sys/bus/pci/devices/${nvidia.pciAddress}/power/control"

    ac_online() {
      [ "$(cat /sys/class/power_supply/${nvidia.acAdapter}/online 2>/dev/null || echo 0)" = "1" ]
    }

    find_niri_session_pid() {
      for pid in $(${pkgs.procps}/bin/pgrep -x niri || true); do
        cmdline="$(${pkgs.coreutils}/bin/tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)"
        case "$cmdline" in
          *"/bin/niri --session"*|*" niri --session"*)
            echo "$pid"
            return 0
            ;;
        esac
      done

      return 1
    }

    is_niri_on_nvidia() {
      niri_pid="$(find_niri_session_pid || true)"
      [ -z "$niri_pid" ] && return 1
      niri_config="$(${pkgs.coreutils}/bin/tr '\0' '\n' < "/proc/$niri_pid/environ" \
        | ${pkgs.gnugrep}/bin/grep '^NIRI_CONFIG=' \
        | ${pkgs.coreutils}/bin/head -n 1 || true)"
      [ -z "$niri_config" ] && return 1
      niri_config="''${niri_config#NIRI_CONFIG=}"
      [ -r "$niri_config" ] && ${pkgs.gnugrep}/bin/grep -q 'render-drm-device "${nvidia.nvidiaRenderNode}"' "$niri_config"
    }

    set_power() {
      mode="$1"
      if [ -f "$GPU_CONTROL" ]; then
        echo "$mode" > "$GPU_CONTROL"
        echo "NVIDIA power control set to $mode"
      fi
    }

    status() {
      echo "=== NVIDIA Power Control Status ==="
      if ac_online; then
        echo "AC Power: Online (Plugged in)"
      else
        echo "AC Power: Offline (On Battery)"
      fi

      if [ -f "$GPU_CONTROL" ]; then
        echo "NVIDIA GPU: Present"
        echo "Current Control: $(cat "$GPU_CONTROL")"
        echo "Runtime Status: $(cat /sys/bus/pci/devices/${nvidia.pciAddress}/power/runtime_status 2>/dev/null || echo unknown)"
      else
        echo "NVIDIA GPU: Not found at ${nvidia.pciAddress}"
      fi

      if is_niri_on_nvidia; then
        echo "Niri Render Config: NVIDIA render node"
      else
        echo "Niri Render Config: Intel/hybrid or not running"
      fi
    }

    case "''${1:-status}" in
      boot|change)
        # Keep the NVIDIA device awake for the external display connector.
        set_power on
        ;;
      ac|on)
        set_power on
        ;;
      battery|auto)
        set_power auto
        ;;
      status)
        status
        ;;
      *)
        echo "usage: $0 [boot|change|ac|battery|status]" >&2
        exit 1
        ;;
    esac
  '';
  temporaryLowPower12w = pkgs.writeShellScriptBin "temporary-low-power-12w" ''
    set -eu

    NVIDIA_PCI_ADDRESS="${nvidia.pciAddress or ""}"
    RAPL_LONG_UW=8000000
    RAPL_SHORT_UW=12000000
    CPU_MAX_PERF_PCT=35

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

    apply_dgpu_runtime_pm() {
      if [ -n "$NVIDIA_PCI_ADDRESS" ]; then
        write_sysfs "/sys/bus/pci/devices/$NVIDIA_PCI_ADDRESS/power/control" auto
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

      for zone in /sys/devices/virtual/powercap/intel-rapl*/intel-rapl*:0; do
        [ -d "$zone" ] || continue
        show_sysfs "$(basename "$zone") long term" "$zone/constraint_0_power_limit_uw"
        show_sysfs "$(basename "$zone") short term" "$zone/constraint_1_power_limit_uw"
      done

      if [ -n "$NVIDIA_PCI_ADDRESS" ]; then
        show_sysfs "NVIDIA power control" "/sys/bus/pci/devices/$NVIDIA_PCI_ADDRESS/power/control"
        show_sysfs "NVIDIA runtime status" "/sys/bus/pci/devices/$NVIDIA_PCI_ADDRESS/power/runtime_status"
      fi
    }

    case "''${1:-apply}" in
      apply)
        apply_platform_profile
        apply_cpu_limits
        apply_rapl_limits
        apply_dgpu_runtime_pm
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
    lib.optional (batteryConservationPath != null) chargeLimit
    ++ lib.optional (nvidia.enable or false) nvidiaPowerControl;

  services.udev.extraRules = lib.concatStringsSep "\n" (
    # Keep latency-sensitive HID devices awake. PowerTOP auto-tuning was putting
    # these behind USB autosuspend, which matched the observed mouse/keyboard stalls.
    map (device:
      ''ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="${device.vendor}", ATTR{idProduct}=="${device.product}", TEST=="power/control", ATTR{power/control}="on"''
    ) keepAwakeUsbDevices
    ++ lib.optional (nvidia.enable or false)
      ''SUBSYSTEM=="power_supply", KERNEL=="${nvidia.acAdapter}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="nvidia-power-control-change.service"''
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
  } // lib.optionalAttrs (nvidia.enable or false) {
    nvidia-power-control-boot = {
      description = "Keep NVIDIA dGPU awake at boot";
      after = [ "local-fs.target" ];
      wantedBy = [ "multi-user.target" ];
      script = "${nvidiaPowerControl}/bin/nvidia-power-control boot";
      serviceConfig.Type = "oneshot";
    };

    nvidia-power-control-change = {
      description = "Keep NVIDIA dGPU awake after AC power changes";
      script = "${nvidiaPowerControl}/bin/nvidia-power-control change";
      serviceConfig.Type = "oneshot";
    };
  };

  specialisation.temporary-low-power-12w.configuration = {
    system.nixos.tags = [ "temporary-low-power-12w" ];
    boot.kernelParams = lib.mkAfter [ "pcie_aspm.policy=powersupersave" ];
    powerManagement.cpuFreqGovernor = lib.mkForce "powersave";
    environment.systemPackages = [ temporaryLowPower12w ];

    systemd.services = {
      temporary-low-power-12w = {
        description = "Apply temporary low-power settings targeting about 12W";
        after = [
          "power-profiles-daemon.service"
          "nvidia-power-control-boot.service"
        ];
        wantedBy = [ "multi-user.target" ];
        path = [
          pkgs.coreutils
          pkgs.power-profiles-daemon
        ];
        script = "${temporaryLowPower12w}/bin/temporary-low-power-12w apply";
        serviceConfig.Type = "oneshot";
      };
    } // lib.optionalAttrs (nvidia.enable or false) {
      nvidia-power-control-boot = {
        description = lib.mkForce "Allow NVIDIA runtime power management in temporary low-power mode";
        script = lib.mkForce "${temporaryLowPower12w}/bin/temporary-low-power-12w apply";
      };

      nvidia-power-control-change = {
        description = lib.mkForce "Keep NVIDIA runtime power management enabled in temporary low-power mode";
        script = lib.mkForce "${temporaryLowPower12w}/bin/temporary-low-power-12w apply";
      };
    };
  };
}
