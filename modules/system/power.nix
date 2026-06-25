{ pkgs, ... }:

let
  nvidiaPowerControl = pkgs.writeShellScriptBin "nvidia-power-control" ''
    set -eu

    GPU_CONTROL="/sys/bus/pci/devices/0000:01:00.0/power/control"

    ac_online() {
      [ "$(cat /sys/class/power_supply/ADP0/online 2>/dev/null || echo 0)" = "1" ]
    }

    is_niri_on_nvidia() {
      niri_pid=$(${pkgs.procps}/bin/pgrep -x niri || true)
      [ -z "$niri_pid" ] && return 1
      ${pkgs.gnugrep}/bin/grep -q "NIRI_CONFIG=.*config-nvidia.kdl" "/proc/$niri_pid/environ" 2>/dev/null
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
        echo "Runtime Status: $(cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status 2>/dev/null || echo unknown)"
      else
        echo "NVIDIA GPU: Not found at 0000:01:00.0"
      fi

      if is_niri_on_nvidia; then
        echo "Niri Session: Running on NVIDIA (dGPU)"
      else
        echo "Niri Session: Running on Intel (iGPU) or not running"
      fi
    }

    case "''${1:-status}" in
      boot|change)
        # dGPU-only mode: keep the NVIDIA device awake until hybrid profiles are stable again.
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

  environment.systemPackages = [ nvidiaPowerControl ];

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
    # Keep latency-sensitive HID devices awake. PowerTOP auto-tuning was putting
    # these behind USB autosuspend, which matched the observed mouse/keyboard stalls.
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="1532", ATTR{idProduct}=="0099", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="320f", ATTR{idProduct}=="5088", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="2109", ATTR{idProduct}=="2822", TEST=="power/control", ATTR{power/control}="on"

    # dGPU-only mode is intentional for now; this keeps the device awake across AC events.
    SUBSYSTEM=="power_supply", KERNEL=="ADP0", TAG+="systemd", ENV{SYSTEMD_WANTS}+="nvidia-power-control-change.service"
  '';

  systemd.services.nvidia-power-control-boot = {
    description = "Keep NVIDIA dGPU awake at boot";
    after = [ "local-fs.target" ];
    wantedBy = [ "multi-user.target" ];
    script = "${nvidiaPowerControl}/bin/nvidia-power-control boot";
    serviceConfig.Type = "oneshot";
  };

  systemd.services.nvidia-power-control-change = {
    description = "Keep NVIDIA dGPU awake after AC power changes";
    script = "${nvidiaPowerControl}/bin/nvidia-power-control change";
    serviceConfig.Type = "oneshot";
  };
}
