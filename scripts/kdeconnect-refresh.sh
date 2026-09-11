# Re-broadcast KDE Connect identity.
# always: used after this computer's network actually changed.
# if-unreachable: skip when a paired device is already reachable, so a phone
# switching Wi-Fi can still be recovered without a constant 2-minute broadcast.
set -euo pipefail

mode=${1:-if-unreachable}

available() {
  kdeconnect-cli --list-available --id-only 2>/dev/null | grep -q .
}

case "$mode" in
  always) ;;
  if-unreachable)
    if available; then
      exit 0
    fi
    ;;
  *)
    echo "usage: kdeconnect-refresh.sh [always|if-unreachable]" >&2
    exit 2
    ;;
esac

exec kdeconnect-cli --refresh
