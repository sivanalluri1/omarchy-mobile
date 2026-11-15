#!/bin/sh
# Self-contained RAM image. No network block device or Android filesystem.
set -eu
[ "$#" -eq 1 ] || { echo 'Usage: mount-arch-ram-root.sh EXPECTED_SHA256' >&2; exit 2; }
case "$1" in *[!0-9a-f]*|'') exit 2;; esac
[ "${#1}" -eq 64 ] || exit 2
[ ! -e /run/arch-root-mounted ] || exit 1
[ -f /arch-root.squashfs ] || exit 1
chmod 600 /arch-root.squashfs
echo "$1  /arch-root.squashfs" | sha256sum -c -
loop=$(losetup -f)
losetup -r "$loop" /arch-root.squashfs
[ "$(blockdev --getro "$loop")" = 1 ] || { losetup -d "$loop"; exit 1; }
mkdir -p /arch
mount -t squashfs -o ro "$loop" /arch
[ -f /arch/etc/arch-release ] || { umount /arch; losetup -d "$loop"; exit 1; }
mkdir -p /dev/shm
/bin/busybox grep -qs ' /dev/shm ' /proc/mounts || mount -t tmpfs -o size=64m,mode=1777 tmpfs /dev/shm
mount --bind /dev /arch/dev
mount --bind /dev/pts /arch/dev/pts
if /bin/busybox grep -qs ' /dev/shm ' /proc/mounts; then mount --bind /dev/shm /arch/dev/shm; fi
mount -t proc proc /arch/proc
mount -t sysfs -o ro sysfs /arch/sys
mount -t tmpfs -o size=64m,mode=755 tmpfs /arch/run
mount -t tmpfs -o size=256m,mode=1777 tmpfs /arch/tmp
mount -t tmpfs -o size=128m,mode=700,uid=1000,gid=1000 tmpfs /arch/home/omarchy
mkdir -p /arch/run/user/1000
chown 1000:1000 /arch/run/user/1000
chmod 700 /arch/run/user/1000
echo "$loop" > /run/arch-root-loop
echo 'compressed RAM image, read-only' > /run/arch-root-transport
touch /run/arch-root-mounted
chroot /arch /bin/bash -c 'ldd --version | head -1; pacman -Q glibc systemd hyprland aquamarine vulkan-icd-loader; id omarchy'
