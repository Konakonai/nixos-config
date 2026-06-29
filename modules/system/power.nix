{ hostProfile, lib, pkgs, ... }:

let
  nvidia = hostProfile.graphics.nvidia or { enable = false; };
  power = hostProfile.power or { };
  batteryConservationPath = power.batteryConservationPath or null;
  keepAwakeUsbDevices = power.keepAwakeUsbDevices or [ ];
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

  environment.systemPackages = lib.optional (nvidia.enable or false) nvidiaPowerControl;

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
}
