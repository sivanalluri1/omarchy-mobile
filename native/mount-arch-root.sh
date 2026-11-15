#!/bin/sh
# Explicit RAM-init experiment; connect only the host's read-only developer disk.
set -eu
[ "$#" -eq 1 ] || { echo 'Usage: mount-arch-root.sh EXPORT_NAME' >&2; exit 2; }
case "$1" in *[!0-9a-f]*|'') echo 'Invalid export name' >&2; exit 2;; esac
[ "${#1}" -eq 48 ] || exit 2
[ -b /dev/nbd0 ] || { echo 'NBD kernel support is required' >&2; exit 1; }
[ ! -e /run/arch-root-mounted ] || exit 1
# Test 05 lost kernel/USB responsiveness on reconnect. Until diagnosed, never
# reconnect or change the exported filesystem within one native boot.
[ ! -e /run/arch-root-connection-used ] || { echo 'Fresh native boot required before another NBD connection' >&2; exit 1; }
touch /run/arch-root-connection-used
mkdir -p /arch
nbd-client -N "$1" -t 30 192.168.77.2 10809 /dev/nbd0
[ "$(blockdev --getro /dev/nbd0)" = 1 ] || { echo 'Export is not read-only' >&2; nbd-client -d /dev/nbd0; exit 1; }
[ "$(blockdev --getsize64 /dev/nbd0)" = 17179869184 ] || { echo 'Unexpected exported image size' >&2; nbd-client -d /dev/nbd0; exit 1; }
mount -t ext4 -o ro,noload /dev/nbd0 /arch
[ -f /arch/etc/arch-release ] || { umount /arch; nbd-client -d /dev/nbd0; exit 1; }
mount --bind /dev /arch/dev
mount --bind /dev/pts /arch/dev/pts
if mountpoint -q /dev/shm; then mount --bind /dev/shm /arch/dev/shm; fi
mount -t proc proc /arch/proc
mount -t sysfs -o ro sysfs /arch/sys
mount -t tmpfs -o size=64m,mode=755 tmpfs /arch/run
mount -t tmpfs -o size=256m,mode=1777 tmpfs /arch/tmp
mount -t tmpfs -o size=128m,mode=700,uid=1000,gid=1000 tmpfs /arch/home/omarchy
mkdir -p /arch/run/user/1000
chown 1000:1000 /arch/run/user/1000
chmod 700 /arch/run/user/1000
touch /run/arch-root-mounted
chroot /arch /bin/bash -c 'cat /etc/arch-release; ldd --version | head -1; pacman -Q glibc systemd hyprland aquamarine; id omarchy'
