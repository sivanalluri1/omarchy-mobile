#!/bin/sh
set -eu
# Stop the desktop/session processes before invoking this helper.
[ -f /run/arch-root-mounted ] || exit 1
umount /arch/home/omarchy /arch/tmp /arch/run /arch/sys /arch/proc /arch/dev
umount /arch
nbd-client -d /dev/nbd0
rm /run/arch-root-mounted
