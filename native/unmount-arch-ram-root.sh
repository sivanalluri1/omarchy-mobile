#!/bin/sh
set -eu
[ -f /run/arch-root-mounted ] && [ -f /run/arch-root-loop ] || exit 1
loop=$(cat /run/arch-root-loop)
case "$loop" in /dev/loop[0-9]*) ;; *) exit 1;; esac
# Desktop and broker processes must be stopped before unmounting.
if [ -s /arch/run/p613-power-button.pid ]; then
  echo 'Stop the Power-button supervisor before unmounting' >&2
  exit 1
fi
if [ -e /run/p613-power-bindings ]; then /tmp/setup-p613-power.sh disable; fi
umount /arch/home/omarchy /arch/tmp /arch/run /arch/sys /arch/proc
umount /arch/dev/shm /arch/dev/pts /arch/dev
umount /arch
losetup -d "$loop"
rm /run/arch-root-mounted /run/arch-root-loop /run/arch-root-transport
