#!/bin/sh
# Wait up to fifteen minutes for physical USB removal; keep gadget configured.
echo waiting_for_cable_removal
cat /proc/uptime
found=0
for attempt in $(seq 1 900); do
    if [ "$(cat /sys/class/power_supply/battery/status)" = Discharging ]; then
        found=1
        break
    fi
    sleep 1
done
if [ "$found" -ne 1 ]; then echo cable_wait_timeout; exit 3; fi
echo cable_removed
cat /proc/uptime
sleep 10
rc=3
for attempt in $(seq 1 15); do
    /tmp/p613-suspend-test deep
    rc=$?
    [ "$rc" -eq 3 ] || break
    sleep 1
done
echo test_exit=$rc
cat /proc/uptime
for f in /sys/power/suspend_stats/* /sys/kernel/wakeup_reasons/*; do echo "$f"; cat "$f"; done
dmesg | tail -120
exit "$rc"
