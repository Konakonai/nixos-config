# Recover USB data on the ThinkBook 16p Type-C ports after a PD event.
#
# pch: the 10 Gbps port, UCSI port1, PCH xHCI SS01 / HS02. PD partners can
#      leave the mux sourcing VBUS without D+/SuperSpeed.
# tb:  the Thunderbolt port, UCSI port0, USB4 xHCI 0000:00:0d.0. Firmware
#      leaves it in UFP with bogus DP alt-modes active and often never
#      registers a typec partner, even for a native USB-C device. Intel USB4
#      sources the connector's USB2 from PCH HS01; SuperSpeed should train on
#      the TB xHCI but frequently stays in RxDetect. Keep the controllers
#      awake and drop those alt-modes on every run, even with a device present.
#
# Both: skip a port that already has a device, give a fresh partner a moment
# to train, bounce the idle xHCI ports, and only then reload UCSI.
#
# usage: reset-usbc.sh pch|tb [reset|rearm|watch|prepare]
# rearm, watch and prepare exist for tb only. SYSROOT overrides sysfs for tests.
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

pch_xhci=${sysroot}/sys/devices/pci0000:00/0000:00:14.0
tb_xhci=${sysroot}/sys/devices/pci0000:00/0000:00:0d.0
name=${1:-}
mode=${2:-reset}

# Ports are bounced in the order listed: USB2 before SuperSpeed.
case "$name:$mode" in
  pch:reset)
    ports=(
      "$pch_xhci/usb3/3-0:1.0/usb3-port2"
      "$pch_xhci/usb4/4-0:1.0/usb4-port1"
    )
    typec_port=port1
    ;;
  tb:reset | tb:rearm | tb:watch | tb:prepare)
    ports=(
      "$pch_xhci/usb3/3-0:1.0/usb3-port1"
      "$tb_xhci/usb1/1-0:1.0/usb1-port1"
      "$tb_xhci/usb2/2-0:1.0/usb2-port1"
      "$tb_xhci/usb2/2-0:1.0/usb2-port2"
    )
    typec_port=port0
    ;;
  *)
    echo "usage: reset-usbc.sh pch | tb [reset|rearm|watch|prepare]" >&2
    exit 2
    ;;
esac
typec=${sysroot}/sys/class/typec/$typec_port
ucsi_drv=${sysroot}/sys/bus/platform/drivers/ucsi_acpi
ucsi_dev=USBC000:00
lock=${sysroot}/run/$name-usbc-reset.lock

log() {
  echo "$name-usbc-reset: $*" >&2
}

port_state() {
  if [ -r "$1/state" ]; then
    cat "$1/state"
  else
    echo missing
  fi
}

states() {
  for port in "${ports[@]}"; do
    printf '%s=%s ' "$(basename "$port")" "$(port_state "$port")"
  done
}

attached() {
  case "$(states)" in
    *configured* | *suspended*)
      return 0
      ;;
  esac
  return 1
}

bounce_ports() {
  for port in "${ports[@]}"; do
    if [ ! -e "$port/disable" ]; then
      log "skip bounce, $port/disable missing"
      continue
    fi
    printf '1\n' > "$port/disable"
    sleep "$bounce_wait"
    printf '0\n' > "$port/disable"
  done
}

wake_tb_pci() {
  for d in 0000:00:0d.0 0000:00:0d.2 0000:00:07.0; do
    ctrl=${sysroot}/sys/bus/pci/devices/$d/power/control
    [ -e "$ctrl" ] || continue
    printf 'on\n' > "$ctrl" 2>/dev/null || true
  done
}

clear_alt_modes() {
  for alt in "$typec/$typec_port.0" "$typec/$typec_port.1"; do
    [ -e "$alt/active" ] || continue
    printf '0\n' > "$alt/active" 2>/dev/null || true
    [ -e "$alt/mode1/active" ] || continue
    printf '0\n' > "$alt/mode1/active" 2>/dev/null || true
  done
  { printf 'host\n' > "$typec/data_role"; } 2>/dev/null || true
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

if [ "$mode" = watch ]; then
  interval=${WATCH_INTERVAL:-4}
  while true; do
    flock 9
    if ! attached; then
      bounce_ports
      sleep "$ucsi_wait"
      if attached; then
        log "watch recovered $(states)"
      fi
    fi
    flock -u 9
    [ -n "${WATCH_ONCE:-}" ] && exit 0
    sleep "$interval"
  done
fi

flock 9

if [ "$name" = tb ]; then
  wake_tb_pci
  clear_alt_modes
fi

if [ "$mode" = prepare ]; then
  log "prepare PCI awake, alt-modes cleared, role=$(cat "$typec/data_role" 2>/dev/null || echo unknown)"
  exit 0
fi

if attached; then
  log "$(states)already has a device, skip"
  exit 0
fi

# Partner add: wait briefly for SuperSpeed to train before touching anything.
if [ -d "$typec/$typec_port-partner" ]; then
  sleep "$settle"
  if attached; then
    log "device appeared while waiting, skip"
    exit 0
  fi
fi

if [ "$mode" = rearm ]; then
  log "rearm bounce $(states)"
  bounce_ports
  log "rearm done $(states)"
  exit 0
fi

log "idle $(states)bounce $name Type-C"
# Clearing alt-modes ends any DisplayPort session, so on the PCH port it only
# happens once its USB ports are known to be idle.
if [ "$name" = pch ]; then
  clear_alt_modes
fi
bounce_ports
sleep "$ucsi_wait"

if attached; then
  log "attached after bounce $(states)"
  exit 0
fi

log "still idle, reload UCSI and bounce again"
reload_ucsi
sleep "$ucsi_wait"
if [ "$name" = tb ]; then
  clear_alt_modes
fi
bounce_ports
sleep "$ucsi_wait"
log "done $(states)role=$(cat "$typec/data_role" 2>/dev/null || echo unknown)"
