#!/bin/sh
# One developer wake-key trial. 90-second RTC fallback; no automatic locking.
set -u
[ "$(uname -r)" = 4.14.357-openela-perf-g21b136df1533 ] || exit 2
[ -f /run/arch-root-mounted ] && [ -x /tmp/p613-suspend-test ] || exit 2
[ "$(chroot /arch /usr/bin/nmcli -t -f WIFI general)" = enabled ] || exit 2
mkdir /run/p613-power-key-test.active || exit 2
user() { chroot /arch /usr/bin/runuser -u omarchy -- /usr/bin/env XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 OMARCHY_PATH=/usr/share/omarchy "$@"; }
on() { user hyprctl -i 0 dispatch 'hl.dsp.dpms({action="on"})'; }
restore() { on; chroot /arch /usr/bin/nmcli radio wifi on; rmdir /run/p613-power-key-test.active; }
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
chroot /arch /usr/bin/nmcli radio wifi off || exit 1
sleep 10
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
chroot /arch /usr/bin/nmcli radio wifi on
[ "$rc" -eq 0 ] || exit "$rc"
sleep 5
user omarchy-shell shell ping || exit 1
user hyprctl -i 0 -j monitors
for attempt in $(seq 1 30); do
    state=$(chroot /arch /usr/bin/nmcli -t -f GENERAL.STATE device show wlan0)
    case "$state" in *100*) break;; esac
    sleep 1
done
chroot /arch /usr/bin/nmcli -t -f GENERAL.STATE device show wlan0
chroot /arch /usr/bin/curl -sS -o /dev/null -w 'https_code=%{http_code}\n' --max-time 15 https://archlinuxarm.org
for f in /sys/power/suspend_stats/* /sys/kernel/wakeup_reasons/*; do echo "$f"; cat "$f"; done
echo POWER_KEY_TEST_FINISHED
