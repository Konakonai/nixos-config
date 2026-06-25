{ pkgs, ... }:

let
  intelPci = "0000:00:02.0";
  nvidiaPci = "0000:01:00.0";
  nvidiaAudioPci = "0000:01:00.1";
  niriRenderConfig = "/run/niri-power-render-device.kdl";

  nvidiaPowerSource = pkgs.writeShellApplication {
    name = "nvidia-power-source";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.power-profiles-daemon
    ];
    text = ''
      set -u

      INTEL_PCI="${intelPci}"
      NVIDIA_PCI="${nvidiaPci}"
      NVIDIA_AUDIO_PCI="${nvidiaAudioPci}"
      NIRI_RENDER_CONFIG="${niriRenderConfig}"

      ac_online() {
        [ "$(cat /sys/class/power_supply/ADP0/online 2>/dev/null || echo 0)" = "1" ]
      }

      set_profile() {
        timeout 1s powerprofilesctl set "$1" 2>/dev/null || true
      }

      pci_present() {
        [ -e "/sys/bus/pci/devices/$1" ]
      }

      render_node_for_pci() {
        pci="$1"

        for node in /sys/class/drm/renderD*; do
          [ -e "$node" ] || continue
          [ "$(basename "$(readlink -f "$node/device" 2>/dev/null)" 2>/dev/null || true)" = "$pci" ] || continue
          echo "/dev/dri/$(basename "$node")"
          return 0
        done

        return 1
      }

      drm_nodes_for_pci() {
        pci="$1"

        for node in /sys/class/drm/card[0-9] /sys/class/drm/renderD*; do
          [ -e "$node" ] || continue
          [ "$(basename "$(readlink -f "$node/device" 2>/dev/null)" 2>/dev/null || true)" = "$pci" ] || continue
          echo "/dev/dri/$(basename "$node")"
        done
      }

      nvidia_display_connected() {
        for status in /sys/class/drm/card*-*/status; do
          [ -e "$status" ] || continue
          [ "$(cat "$status" 2>/dev/null || true)" = "connected" ] || continue

          connector="''${status%/status}"
          card="''${connector##*/}"
          card="''${card%%-*}"

          [ "$(basename "$(readlink -f "/sys/class/drm/$card/device" 2>/dev/null)" 2>/dev/null || true)" = "$NVIDIA_PCI" ] || continue
          return 0
        done

        return 1
      }

      set_runtime_power() {
        value="$1"

        for dev in "$NVIDIA_AUDIO_PCI" "$NVIDIA_PCI"; do
          control="/sys/bus/pci/devices/$dev/power/control"
          [ -w "$control" ] && echo "$value" > "$control" 2>/dev/null || true
        done
      }

      write_niri_render_config() {
        mode="$1"

        mkdir -p "$(dirname "$NIRI_RENDER_CONFIG")"

        case "$mode" in
          intel)
            render_node="$(render_node_for_pci "$INTEL_PCI" || true)"
            ;;
          nvidia)
            render_node="$(render_node_for_pci "$NVIDIA_PCI" || true)"
            ;;
          *)
            render_node=""
            ;;
        esac

        if [ -n "$render_node" ]; then
          printf 'debug {\n    render-drm-device "%s"\n}\n' "$render_node" > "$NIRI_RENDER_CONFIG"
          return 0
        fi

        : > "$NIRI_RENDER_CONFIG"
      }

      nvidia_client_pids() {
        {
          echo "/dev/nvidia*"
          drm_nodes_for_pci "$NVIDIA_PCI"
        } | while read -r node; do
          [ -n "$node" ] || continue
          find /proc/[0-9]*/fd -lname "$node" -printf "%h\n" 2>/dev/null || true
        done \
          | sed 's#/proc/##; s#/fd##' \
          | sort -u \
          | while read -r pid; do
            [ -n "$pid" ] || continue
            comm="$(cat "/proc/$pid/comm" 2>/dev/null || true)"
            echo "$pid:''${comm:-unknown}"
          done
      }

      battery_nvidia() {
        set_profile power-saver
        write_niri_render_config intel
        set_runtime_power auto
      }

      ac_nvidia() {
        set_profile balanced
        if nvidia_display_connected; then
          write_niri_render_config nvidia
        else
          write_niri_render_config auto
        fi
        set_runtime_power on
      }

      status_nvidia() {
        if ac_online; then
          echo "ac"
        else
          echo "battery"
        fi

        if pci_present "$NVIDIA_PCI"; then
          echo "nvidia: present"
          cat "/sys/bus/pci/devices/$NVIDIA_PCI/power/runtime_status" 2>/dev/null || true
          cat "/sys/bus/pci/devices/$NVIDIA_PCI/power/control" 2>/dev/null || true
        else
          echo "nvidia: absent"
        fi

        if nvidia_display_connected; then
          echo "nvidia-display: connected"
        else
          echo "nvidia-display: disconnected"
        fi

        if [ -s "$NIRI_RENDER_CONFIG" ]; then
          echo "niri-render: $(grep -m1 'render-drm-device' "$NIRI_RENDER_CONFIG" | sed 's/^[[:space:]]*//')"
        else
          echo "niri-render: auto"
        fi

        clients="$(nvidia_client_pids)"
        if [ -n "$clients" ]; then
          echo "clients:"
          echo "$clients"
        else
          echo "clients: none"
        fi
      }

      case "''${1:-auto}" in
        auto)
          if ac_online; then
            ac_nvidia
          else
            battery_nvidia
          fi
          ;;
        battery|powersave)
          battery_nvidia
          ;;
        ac|performance)
          ac_nvidia
          ;;
        status)
          status_nvidia
          ;;
        *)
          echo "usage: nvidia-power-source [auto|battery|ac|status]" >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  environment.systemPackages = [ nvidiaPowerSource ];

  systemd.tmpfiles.rules = [
    "f ${niriRenderConfig} 0664 root users - -"
  ];

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", RUN+="/bin/sh -c 'chown root:users /sys/bus/pci/devices/$kernel/power/control 2>/dev/null || true; chmod 664 /sys/bus/pci/devices/$kernel/power/control 2>/dev/null || true'"
  '';

  systemd.services.nvidia-power-control-permissions = {
    description = "Allow users group to adjust NVIDIA runtime power control";
    after = [ "systemd-udevd.service" ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      for dev in ${nvidiaAudioPci} ${nvidiaPci}; do
        control="/sys/bus/pci/devices/$dev/power/control"
        if [ -f "$control" ]; then
          chown root:users "$control"
          chmod 664 "$control"
        fi
      done
    '';
    serviceConfig.Type = "oneshot";
  };

  systemd.services.nvidia-power-source-boot = {
    description = "Apply NVIDIA offload policy based on AC power at boot";
    before = [
      "display-manager.service"
      "greetd.service"
    ];
    after = [ "local-fs.target" ];
    wantedBy = [ "graphical.target" ];
    script = ''
      ${nvidiaPowerSource}/bin/nvidia-power-source auto
    '';
    serviceConfig = {
      Type = "oneshot";
      TimeoutSec = "3s";
    };
  };

  systemd.services.nvidia-power-source-battery = {
    description = "Prefer NVIDIA runtime suspend when AC power is disconnected";
    script = ''
      ${nvidiaPowerSource}/bin/nvidia-power-source battery
    '';
    serviceConfig = {
      Type = "oneshot";
      TimeoutSec = "3s";
    };
  };

  systemd.services.nvidia-power-source-ac = {
    description = "Keep NVIDIA ready when AC power is connected";
    script = ''
      ${nvidiaPowerSource}/bin/nvidia-power-source ac
    '';
    serviceConfig = {
      Type = "oneshot";
      TimeoutSec = "3s";
    };
  };
}
