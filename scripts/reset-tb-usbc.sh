# Recover USB data on the ThinkBook 16p Thunderbolt Type-C port (UCSI port0).
# The USB4 xHCI is 0000:00:0d.0. Firmware leaves port0 in UFP with bogus DP
# alt-modes active; PD then sources VBUS without SuperSpeed. Keep the NHI
# awake, drop those alt-modes, bounce the TB xHCI ports, and only then
# reload UCSI if still idle.
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
ss=${sysroot}/sys/devices/pci0000:00/0000:00:0d.0/usb2/2-0:1.0/usb2-port1
ss2=${sysroot}/sys/devices/pci0000:00/0000:00:0d.0/usb2/2-0:1.0/usb2-port2
hs=${sysroot}/sys/devices/pci0000:00/0000:00:0d.0/usb1/1-0:1.0/usb1-port1
typec=${sysroot}/sys/class/typec/port0
ucsi_drv=${sysroot}/sys/bus/platform/drivers/ucsi_acpi
ucsi_dev=USBC000:00
lock=${sysroot}/run/tb-usbc-reset.lock
mode=${1:-reset}

log() {
  echo "tb-usbc-reset: $*" >&2
}

port_state() {
  if [ -r "$1/state" ]; then
    cat "$1/state"
  else
    echo missing
  fi
}

attached() {
  case "$(port_state "$ss") $(port_state "$ss2") $(port_state "$hs")" in
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

wake_pci() {
  for d in 0000:00:0d.0 0000:00:0d.2 0000:00:07.0; do
    ctrl=${sysroot}/sys/bus/pci/devices/$d/power/control
    [ -e "$ctrl" ] || continue
    printf 'on\n' > "$ctrl" 2>/dev/null || true
  done
}

deactivate_alt_modes() {
  for alt in "$typec"/port0.0 "$typec"/port0.1; do
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

wake_pci
deactivate_alt_modes
try_host_role

if [ "$mode" = prepare ]; then
  log "prepare PCI awake, alt-modes cleared, role=$(cat "$typec/data_role" 2>/dev/null || echo unknown)"
  exit 0
fi

if attached; then
  log "SS=$(port_state "$ss") HS=$(port_state "$hs"); already has a device, skip"
  exit 0
fi

if [ -d "$typec/port0-partner" ]; then
  sleep "$settle"
  if attached; then
    log "device appeared while waiting, skip"
    exit 0
  fi
fi

log "idle SS=$(port_state "$ss") HS=$(port_state "$hs"); bounce Thunderbolt USB"
bounce "$hs"
bounce "$ss"
bounce "$ss2"
sleep "$ucsi_wait"

if attached; then
  log "attached after bounce SS=$(port_state "$ss") HS=$(port_state "$hs")"
  exit 0
fi

log "still idle, reload UCSI and bounce again"
reload_ucsi
sleep "$ucsi_wait"
deactivate_alt_modes
try_host_role
bounce "$hs"
bounce "$ss"
bounce "$ss2"
sleep "$ucsi_wait"
log "done SS=$(port_state "$ss") HS=$(port_state "$hs") role=$(cat "$typec/data_role" 2>/dev/null || echo unknown)"
