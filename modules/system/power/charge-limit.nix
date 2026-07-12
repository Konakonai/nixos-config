{ hostProfile, lib, pkgs, ... }:

let
  power = hostProfile.power or { };
  batteryConservationPath = power.batteryConservationPath or null;
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
in
{
  environment.systemPackages = lib.optional (batteryConservationPath != null) chargeLimit;

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
}
