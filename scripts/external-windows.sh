# Start the external Windows libvirt domain after confirming disk and guest state.
# Commands are resolved from PATH so tests can inject fakes.
set -euo pipefail

domain=${EXTERNAL_WINDOWS_DOMAIN:?}
disk=${EXTERNAL_WINDOWS_DISK:?}
connection=${EXTERNAL_WINDOWS_CONNECTION:-qemu:///system}

fail() {
  notify-send --urgency=critical "External Windows" "$1" || true
  zenity --error --title="External Windows" --text="$1" || true
  exit 1
}

mounted_names() {
  jq -r '
    .blockdevices[]
    | recurse(.children[]?)
    | select(any(.mountpoints[]?; . != null))
    | .name
  '
}

probe_mounted() {
  local json
  json=$(lsblk --json --paths --output NAME,MOUNTPOINTS "$disk") || return 2
  printf '%s' "$json" | mounted_names || return 3
}

require_disk_state() {
  local status=0
  mounted=$(probe_mounted) || status=$?
  case "$status" in
    0) ;;
    2) fail "The aigo U397 Windows disk is not connected." ;;
    *) fail "Could not parse disk topology for $disk." ;;
  esac
}

require_disk_state

if ! vm_list=$(virsh --connect "$connection" list --name); then
  fail "Could not query libvirt for $domain."
fi

if printf '%s\n' "$vm_list" | grep --fixed-strings --line-regexp --quiet "$domain"; then
  exec virt-viewer --connect "$connection" --wait --reconnect "$domain"
fi

if [[ -n "$mounted" ]]; then
  while IFS= read -r device; do
    [[ -z "$device" ]] && continue
    udisksctl unmount --block-device "$device" ||
      fail "Could not unmount $device. Close files using the Windows disk and retry."
  done <<< "$mounted"
fi

require_disk_state
if [[ -n "$mounted" ]]; then
  fail "A Windows disk partition is still mounted. The VM was not started."
fi

virsh --connect "$connection" start "$domain" ||
  fail "libvirt could not start $domain. Open Virtual Machine Manager for details."

exec virt-viewer --connect "$connection" --wait --reconnect "$domain"
