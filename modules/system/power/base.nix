{ pkgs, ... }:

let
  thermalProfile = pkgs.writeShellScriptBin "thermal-profile" ''
    set -eu

    powerprofilesctl="${pkgs.power-profiles-daemon}/bin/powerprofilesctl"

    notify() {
      ${pkgs.libnotify}/bin/notify-send \
        --app-name=thermal-profile \
        "Thermal profile" \
        "$1" >/dev/null 2>&1 || true
    }

    current_profile() {
      "$powerprofilesctl" get 2>/dev/null || echo balanced
    }

    set_profile() {
      profile="$1"
      case "$profile" in
        balanced)
          label="Balanced"
          ;;
        performance)
          label="Performance"
          ;;
        power-saver)
          label="Power saver"
          ;;
        *)
          echo "unknown thermal profile: $profile" >&2
          exit 2
          ;;
      esac

      "$powerprofilesctl" set "$profile"
      echo "$profile"
      notify "$label"
    }

    case "''${1:-toggle}" in
      toggle)
        case "$(current_profile)" in
          performance)
            set_profile balanced
            ;;
          *)
            set_profile performance
            ;;
        esac
        ;;
      balanced|performance|power-saver)
        set_profile "$1"
        ;;
      status)
        current_profile
        if [ -r /sys/firmware/acpi/platform_profile ]; then
          printf 'platform_profile='
          cat /sys/firmware/acpi/platform_profile
        fi
        ;;
      *)
        echo "usage: thermal-profile [toggle|balanced|performance|power-saver|status]" >&2
        exit 2
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

  services.logind.settings.Login = {
    # The panel already powers off when the lid is physically closed; keep the
    # system awake to avoid unreliable s2idle resume on this machine.
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  powerManagement.powertop.enable = false;

  environment.systemPackages = [ thermalProfile ];
}
