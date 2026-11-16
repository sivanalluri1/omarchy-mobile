#!/bin/sh
set -eu
[ "$(uname -r)" = 4.14.357-openela-perf-g21b136df1533 ]
[ -f /run/arch-root-mounted ]
for item in networkmanager:NetworkManager system-wpa:wpa_supplicant system-dbus:dbus-daemon; do
    name=${item%%:*}; expected=${item#*:}
    file=/run/p613-$name.pid
    if [ -f "$file" ]; then
        pid=$(cat "$file")
        case "$pid" in ''|*[!0-9]*) exit 1;; esac
        if [ "$(cat /proc/$pid/comm 2>/dev/null || true)" = "$expected" ]; then
            kill -TERM "$pid"
        fi
        rm -f "$file"
    fi
done
sleep 2
for target in /arch/etc/resolv.conf /arch/etc/machine-id /arch/etc/NetworkManager/system-connections /arch/var/lib/NetworkManager; do
    if grep -qs " $target " /proc/mounts; then umount "$target"; fi
done
rm -f /run/p613-network-active
echo P613_NETWORK_SERVICES_STOPPED
