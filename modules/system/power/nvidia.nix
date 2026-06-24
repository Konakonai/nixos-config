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
  environment.systemPackages = [ nvidiaPowerSource ];

  services.udev.extraRules = ''
    # Allow the users group to power down the dGPU when it appears after boot or PCI rescan.
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{device}=="0x28e0", RUN+="/bin/sh -c 'chown root:users /sys/bus/pci/devices/$kernel/remove /sys/bus/pci/devices/$kernel/power/control 2>/dev/null || true; chmod 664 /sys/bus/pci/devices/$kernel/remove /sys/bus/pci/devices/$kernel/power/control 2>/dev/null || true'"
  '';

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
}
