#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/scripts/storage.sh"
require_ssd_storage
docker run --rm --network none --cap-add SYS_ADMIN \
  --device-cgroup-rule 'b 7:* rwm' --device-cgroup-rule 'c 10:237 rwm' \
  --mount "type=bind,src=$OMARCHY_LINUX_ROOT/build/arch-ram/arch-root.squashfs,dst=/image/root.squashfs,readonly" \
  omarchy-p613-ram-root:debian13 bash -c '
set -euo pipefail
mknod /dev/loop-control c 10 237
for n in $(seq 0 63); do mknod "/dev/loop$n" b 7 "$n"; done
loop=$(losetup --read-only --find --show /image/root.squashfs)
mkdir /target
cleanup() { umount -R /target; losetup -d "$loop"; }
trap cleanup EXIT
mount -t squashfs -o ro "$loop" /target
mount --rbind /dev /target/dev
mount --make-rslave /target/dev
mount -t proc proc /target/proc
mount -t tmpfs -o mode=1777 tmpfs /target/tmp
mkdir /target/tmp/runtime
chown 1000:1000 /target/tmp/runtime
chmod 700 /target/tmp/runtime
chroot /target /bin/bash -c '\''ldd --version | head -1; pacman -Q hyprland aquamarine vulkan-icd-loader; id omarchy'\''
chroot /target /usr/bin/runuser -u omarchy -- /usr/bin/env XDG_RUNTIME_DIR=/tmp/runtime \
  /usr/bin/Hyprland --verify-config --config /etc/p613/hyprland-test.lua
chroot /target /usr/bin/runuser -u omarchy -- /usr/bin/script -q -c "printf PTY_PROBE_PASS" /dev/null
chroot /target /usr/bin/env LD_LIBRARY_PATH=/opt/p613-gpu/lib /usr/bin/ldd /opt/p613-gpu/lib/libvulkan_freedreno.so
' 2>&1 | tee "$root/build/arch-ram-root-validation.log"
! rg -q 'not found' "$root/build/arch-ram-root-validation.log"
