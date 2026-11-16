#!/bin/sh
# Native RAM service experiment, separate from the recovery USB network.
set -eu
[ "$(uname -r)" = 4.14.357-openela-perf-g21b136df1533 ]
[ -f /run/arch-root-mounted ]
[ -d /sys/class/net/wlan0 ]
[ ! -e /run/p613-network-active ]
[ -f /arch/etc/p613/NetworkManager.conf ]
mkdir -p /arch/var/lib/NetworkManager
mount -t tmpfs -o size=16m,mode=700 tmpfs /arch/var/lib/NetworkManager
mount -t tmpfs -o size=4m,mode=700 tmpfs /arch/etc/NetworkManager/system-connections
mkdir -p /arch/run/dbus /arch/run/NetworkManager/system-connections
chmod 700 /arch/run/NetworkManager/system-connections
chroot /arch /usr/bin/dbus-uuidgen --ensure=/run/p613-machine-id
mount --bind /arch/run/p613-machine-id /arch/etc/machine-id
chroot /arch /usr/bin/dbus-daemon --system --nofork --nopidfile >/arch/tmp/system-dbus.log 2>&1 </dev/null &
echo $! >/run/p613-system-dbus.pid
count=0
while [ ! -S /arch/run/dbus/system_bus_socket ]; do
    count=$((count+1)); [ "$count" -lt 20 ]; sleep 1
done
chroot /arch /usr/bin/wpa_supplicant -u -O /run/wpa_supplicant -f /tmp/p613-wpa-system.log >/arch/tmp/wpa-system-wrapper.log 2>&1 </dev/null &
echo $! >/run/p613-system-wpa.pid
chroot /arch /usr/bin/env LD_LIBRARY_PATH=/opt/p613-compat/lib \
    /usr/bin/NetworkManager --no-daemon --config=/etc/p613/NetworkManager.conf \
    --state-file=/run/NetworkManager/state --pid-file=/run/NetworkManager.pid \
    >/arch/tmp/NetworkManager.log 2>&1 </dev/null &
echo $! >/run/p613-networkmanager.pid
count=0
until chroot /arch /usr/bin/nmcli general status >/dev/null 2>&1; do
    count=$((count+1)); [ "$count" -lt 30 ]; sleep 1
done
test "$(chroot /arch /usr/bin/nmcli -g GENERAL.NM-MANAGED device show usb0)" = no
test "$(chroot /arch /usr/bin/nmcli -g GENERAL.NM-MANAGED device show wlan0)" = yes
touch /run/p613-network-active
echo P613_NETWORKMANAGER_READY
