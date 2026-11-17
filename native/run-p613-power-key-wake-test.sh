#!/bin/sh
# One developer wake-key trial. 90-second RTC fallback; no automatic locking.
set -u
[ "$(uname -r)" = 4.14.357-openela-perf-g21b136df1533 ] || exit 2
[ -f /run/arch-root-mounted ] && [ -x /tmp/p613-suspend-test ] || exit 2
use_network=${P613_POWER_KEY_USE_NETWORK:-1}
case "$use_network" in 0|1) ;; *) exit 2;; esac
if [ "$use_network" = 1 ]; then
    [ "$(chroot /arch /usr/bin/nmcli -t -f WIFI general)" = enabled ] || exit 2
else
    [ ! -e /run/p613-radio-active ] || exit 2
fi
pm_mode=${P613_POWER_KEY_PM_ASYNC:-keep}
case "$pm_mode" in keep|0) ;; *) exit 2;; esac
saved_pm_async=$(cat /sys/power/pm_async)
expect_connected=0
if [ "$use_network" = 1 ]; then
    case "$(chroot /arch /usr/bin/nmcli -t -f GENERAL.STATE device show wlan0)" in *100*) expect_connected=1;; esac
fi
mkdir /run/p613-power-key-test.active || exit 2
user() { chroot /arch /usr/bin/runuser -u omarchy -- /usr/bin/env XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 OMARCHY_PATH=/usr/share/omarchy "$@"; }
on() { user hyprctl -i 0 dispatch 'hl.dsp.dpms({action="on"})'; }
wifi_on() { if [ "$use_network" = 1 ]; then chroot /arch /usr/bin/nmcli radio wifi on; fi; }
restore() {
    on; wifi_on
    if [ "$pm_mode" = 0 ]; then printf '%s' "$saved_pm_async" > /sys/power/pm_async; fi
    rmdir /run/p613-power-key-test.active
}
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
if [ "$use_network" = 1 ]; then chroot /arch /usr/bin/nmcli radio wifi off || exit 1; fi
sleep 10
if [ "$pm_mode" = 0 ]; then echo 0 > /sys/power/pm_async || exit 1; fi
echo PM_ASYNC=$(cat /sys/power/pm_async)
echo POWER_KEY_BASELINE
grep pon_kpdpwr_status /proc/interrupts
user hyprctl -i 0 dispatch 'hl.dsp.dpms({action="off"})' || exit 1
sleep 2
rc=3
for attempt in $(seq 1 10); do
    /tmp/p613-suspend-test button
    rc=$?
    case "$rc" in 3|4) sleep 2;; *) break;; esac
done
echo suspend_exit=$rc
echo POWER_KEY_AFTER
grep pon_kpdpwr_status /proc/interrupts
on
wifi_on
[ "$rc" -eq 0 ] || exit "$rc"
sleep 5
user omarchy-shell shell ping || exit 1
user hyprctl -i 0 -j monitors
if [ "$use_network" = 1 ] && [ "$expect_connected" = 1 ]; then
for attempt in $(seq 1 30); do
    state=$(chroot /arch /usr/bin/nmcli -t -f GENERAL.STATE device show wlan0)
    case "$state" in *100*) break;; esac
    sleep 1
done
chroot /arch /usr/bin/nmcli -t -f GENERAL.STATE device show wlan0
chroot /arch /usr/bin/curl -sS -o /dev/null -w 'https_code=%{http_code}\n' --max-time 15 https://archlinuxarm.org
else
    echo NETWORK_CONNECTION_NOT_REQUIRED_FOR_THIS_TRIAL
fi
for f in /sys/power/suspend_stats/* /sys/kernel/wakeup_reasons/*; do echo "$f"; cat "$f"; done
echo POWER_KEY_TEST_FINISHED
