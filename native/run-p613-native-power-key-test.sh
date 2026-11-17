#!/bin/sh
# Headless native wake-key trial. Arm a 90-second RTC fallback before suspend.
set -u
[ "$(uname -r)" = 4.14.357-openela-perf-g21b136df1533 ] || exit 2
[ ! -e /run/arch-root-mounted ] && [ ! -e /run/p613-radio-active ] || exit 2
[ -x /tmp/p613-suspend-test ] || exit 2
pm_mode=${P613_POWER_KEY_PM_ASYNC:-keep}
case "$pm_mode" in keep|0) ;; *) exit 2;; esac
saved_pm_async=$(cat /sys/power/pm_async)
restore() { if [ "$pm_mode" = 0 ]; then printf '%s' "$saved_pm_async" > /sys/power/pm_async; fi; }
trap restore EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
echo waiting_for_cable_removal
found=0
for attempt in $(seq 1 900); do
    if [ "$(cat /sys/class/power_supply/battery/status)" = Discharging ]; then found=1; break; fi
    sleep 1
done
[ "$found" -eq 1 ] || exit 3
echo cable_removed
cat /proc/uptime
sleep 10
if [ "$pm_mode" = 0 ]; then echo 0 > /sys/power/pm_async || exit 1; fi
echo PM_ASYNC=$(cat /sys/power/pm_async)
echo POWER_KEY_BASELINE
grep pon_kpdpwr_status /proc/interrupts
rc=3
for attempt in $(seq 1 10); do
    /tmp/p613-suspend-test button
    rc=$?
    case "$rc" in 3|4) sleep 2;; *) break;; esac
done
echo suspend_exit=$rc
echo POWER_KEY_AFTER
grep pon_kpdpwr_status /proc/interrupts
cat /proc/uptime
for f in /sys/power/suspend_stats/* /sys/kernel/wakeup_reasons/*; do echo "$f"; cat "$f"; done
dmesg | tail -100
echo NATIVE_POWER_KEY_TEST_FINISHED
exit "$rc"
