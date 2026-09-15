# Recover USB data on the ThinkBook 16p PCH Type-C port (SS01 / HS02).
# PD partners can leave the mux sourcing VBUS without D+/SuperSpeed. Bounce
# those two xHCI ports, and only then reload UCSI if still idle.
# SYSROOT overrides sysfs for tests.
set -euo pipefail

sysroot=${SYSROOT:-}
if [ -n "$sysroot" ]; then
  settle=0
  bounce_wait=0
  ucsi_wait=0
else
  settle=2
  bounce_wait=0.3
  ucsi_wait=1
fi
ss=${sysroot}/sys/devices/pci0000:00/0000:00:14.0/usb4/4-0:1.0/usb4-port1
hs=${sysroot}/sys/devices/pci0000:00/0000:00:14.0/usb3/3-0:1.0/usb3-port2
typec=${sysroot}/sys/class/typec/port1
ucsi_drv=${sysroot}/sys/bus/platform/drivers/ucsi_acpi
ucsi_dev=USBC000:00
lock=${sysroot}/run/pch-usbc-reset.lock

log() {
  echo "pch-usbc-reset: $*" >&2
}

port_state() {
  if [ -r "$1/state" ]; then
    cat "$1/state"
  else
    echo missing
  fi
}

attached() {
  case "$(port_state "$ss") $(port_state "$hs")" in
    *configured* | *suspended*)
      return 0
      ;;
  esac
  return 1
}

bounce() {
  port=$1
  if [ ! -e "$port/disable" ]; then
    log "skip bounce, $port/disable missing"
    return 0
  fi
  printf '1\n' > "$port/disable"
  sleep "$bounce_wait"
  printf '0\n' > "$port/disable"
}

deactivate_alt_modes() {
  for alt in "$typec"/port1.0 "$typec"/port1.1; do
    [ -e "$alt/active" ] || continue
    printf '0\n' > "$alt/active" 2>/dev/null || true
    [ -e "$alt/mode1/active" ] || continue
    printf '0\n' > "$alt/mode1/active" 2>/dev/null || true
  done
}

try_host_role() {
  if [ -w "$typec/data_role" ]; then
    printf 'host\n' > "$typec/data_role" || true
  fi
}

reload_ucsi() {
  if [ ! -e "$ucsi_drv/unbind" ] || [ ! -e "$ucsi_drv/bind" ]; then
    log "UCSI sysfs missing, skip reload"
    return 0
  fi
  printf '%s\n' "$ucsi_dev" > "$ucsi_drv/unbind" 2>/dev/null || true
  sleep "$ucsi_wait"
  printf '%s\n' "$ucsi_dev" > "$ucsi_drv/bind" 2>/dev/null || true
}

mkdir -p "$(dirname "$lock")"
exec 9>"$lock"
flock 9

if attached; then
  log "SS01=$(port_state "$ss") HS02=$(port_state "$hs"); already has a device, skip"
  exit 0
fi

# Partner add: wait briefly for SuperSpeed to train before touching anything.
if [ -d "$typec/port1-partner" ]; then
  sleep "$settle"
  if attached; then
    log "device appeared while waiting, skip"
    exit 0
  fi
fi

log "idle SS01=$(port_state "$ss") HS02=$(port_state "$hs"); bounce PCH Type-C"
deactivate_alt_modes
try_host_role
bounce "$hs"
bounce "$ss"
sleep "$ucsi_wait"

if attached; then
  log "attached after bounce SS01=$(port_state "$ss") HS02=$(port_state "$hs")"
  exit 0
fi

log "still idle, reload UCSI and bounce again"
reload_ucsi
sleep "$ucsi_wait"
bounce "$hs"
bounce "$ss"
sleep "$ucsi_wait"
log "done SS01=$(port_state "$ss") HS02=$(port_state "$hs")"
