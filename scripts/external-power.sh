# Exit 0 if any non-battery power supply is online.
#
# ADP0 is only the barrel jack. A Type-C PD source (the Thunderbolt
# monitor) keeps ucsi-source-psy-USBC000:001 online while ADP0 reads 0
# (measured 2026-11-13: barrel unplug with the monitor still attached).
# SYSROOT overrides sysfs for tests.
set -euo pipefail

sysroot=${SYSROOT:-}
shopt -s nullglob
for dir in "${sysroot}"/sys/class/power_supply/*; do
  [ -r "$dir/type" ] && [ -r "$dir/online" ] || continue
  read -r type < "$dir/type"
  [ "$type" = Battery ] && continue
  read -r online < "$dir/online"
  [ "$online" = 1 ] && exit 0
done
exit 1
