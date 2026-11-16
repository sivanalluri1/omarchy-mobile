#!/bin/sh
# Retire the temporary supplicant when the supervised native radio test ends.
set -eu
[ "$(uname -r)" = 4.14.357-openela-perf-g21b136df1533 ]
[ -f /run/arch-root-mounted ]
while [ -e /run/p613-radio-active ]; do sleep 5; done
if [ -f /arch/run/p613-wpa.pid ]; then
    pid=$(cat /arch/run/p613-wpa.pid)
    case "$pid" in ''|*[!0-9]*) exit 1;; esac
    if [ "$(cat "/proc/$pid/comm" 2>/dev/null || true)" = wpa_supplicant ]; then
        kill -TERM "$pid"
    fi
    rm -f /arch/run/p613-wpa.pid
fi
rm -f /arch/tmp/p613-wpa.conf /arch/home/omarchy/.local/state/p613-wifi/request.conf
