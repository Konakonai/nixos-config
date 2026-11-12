# Exit 0 if any non-battery power supply is online.
#
# ADP0 is the ACPI AC adapter. A Type-C PD contract shows up on
# ucsi-source-psy-* immediately, but the EC only marks ADP0 online about
# 5 s later (measured 2026-11-13: barrel unplug with the Thunderbolt
# monitor still attached; ADP0 dropped, then returned to 1 and stayed
# there). Checking every non-battery supply covers that gap.
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
