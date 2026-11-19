#!/bin/sh
# Temporary key-only control during USB host/OTG tests. Native RAM root only.
set -eu
[ "$(id -u)" = 0 ]
[ "$(uname -r)" = 4.14.357-openela-perf-g21b136df1533 ]
[ -f /run/arch-root-mounted ]
[ -s /root/.ssh/authorized_keys ]
seconds=${P613_LAN_SSH_SECONDS:-1800}
case "$seconds" in ''|*[!0-9]*) exit 2;; esac
[ "$seconds" -ge 30 ] && [ "$seconds" -le 3600 ]
address=$(ip -4 -o addr show dev wlan0 scope global | awk '{split($4,a,"/"); print a[1]}')
[ -n "$address" ]
# Reject multiple addresses; bind only the currently connected WLAN address.
[ "$(printf '%s\n' "$address" | wc -l)" -eq 1 ]
mkdir /run/p613-lan-ssh.lock
server=''
timer=''
cleanup() {
    trap - EXIT INT TERM
    for child in "$server" "$timer"; do
        [ -z "$child" ] || kill -TERM "$child" 2>/dev/null || true
    done
    [ -z "$server" ] || wait "$server" 2>/dev/null || true
    [ -z "$timer" ] || wait "$timer" 2>/dev/null || true
    rm -f /run/p613-lan-ssh.lock/pid
    rmdir /run/p613-lan-ssh.lock
}
trap cleanup EXIT
trap 'exit 143' INT TERM
echo $$ >/run/p613-lan-ssh.lock/pid
/usr/sbin/dropbear -F -E -s -j -k -r /etc/dropbear/dropbear_ed25519_host_key -p "$address:2222" &
server=$!
sleep 1
kill -0 "$server"
echo "P613_LAN_SSH_READY address=$address port=2222 duration=${seconds}s"
sleep "$seconds" &
timer=$!
wait "$timer"
