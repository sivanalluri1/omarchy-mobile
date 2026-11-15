#!/usr/bin/env bash
# Container only: SSD-backed ext4 FILE, never a host disk or tablet partition.
set -euo pipefail
mode=${1:?bootstrap|packages|inspect}
image=/out/arch-root.img
mknod /dev/loop-control c 10 237
for n in $(seq 0 63); do mknod "/dev/loop$n" b 7 "$n"; done
if [ "$mode" = bootstrap ]; then
  [ ! -e "$image" ] || { echo 'Refusing to overwrite an existing root image' >&2; exit 1; }
  echo '42a4eeaa038994ffd31fa173256ef2f0ef511358eeb41b9ea1f8626391b9b319  /input/ArchLinuxARM-aarch64-latest.tar.gz' | sha256sum -c -
  truncate -s 16G "$image"
  # orphan_file is too new for the vendor 4.14 ext4 driver.
  mkfs.ext4 -q -m 0 -L p613-arch -O ^orphan_file,^metadata_csum_seed "$image"
fi
[ -f "$image" ] || exit 1
loop=$(losetup --find --show "$image")
mkdir -p /target
cleanup() {
  if mountpoint -q /target; then
    if [ -x /target/usr/bin/gpgconf ] && [ -c /target/dev/null ]; then
      chroot /target /usr/bin/gpgconf --homedir /etc/pacman.d/gnupg --kill all || true
    fi
    if ! umount -R /target; then
      losetup -d "$loop"  # Mark for detach when the container's mounts close.
      return 1
    fi
  fi
  losetup -d "$loop"
}
trap cleanup EXIT
mount "$loop" /target
case "$mode" in
bootstrap)
  bsdtar -xpf /input/ArchLinuxARM-aarch64-latest.tar.gz -C /target --numeric-owner
  chroot /target /bin/bash -c 'uname -m; ldd --version | head -1; pacman -Q systemd glibc bash pacman'
  ;;
packages|finalize)
  printf 'Server = https://fl.us.mirror.archlinuxarm.org/$arch/$repo\n' > /target/etc/pacman.d/mirrorlist
  cp --remove-destination /etc/resolv.conf /target/etc/resolv.conf
  mount -t proc proc /target/proc
  mount --rbind /dev /target/dev
  mount --make-rslave /target/dev
  mount -t sysfs -o ro sysfs /target/sys
  if [ "$mode" = packages ]; then
    chroot /target /bin/bash -s < /project/scripts/configure-arch-inside.sh
  else
    chroot /target /bin/bash -s < /project/scripts/finalize-arch-inside.sh
    mkdir -p /target/opt /target/etc/p613 /target/usr/local/bin
    cp -a /gpu-stage /target/opt/p613-gpu
    # Mesa's already-proven DRM/WSI build needs the 0.2 SONAME; Arch has 0.3.
    # Keep this leaf compatibility library private to the Mesa prefix.
    cp /compat/libdisplay-info.so.2 /target/opt/p613-gpu/lib/libdisplay-info.so.2
    cp /project/configs/hyprland-p613-test.lua /target/etc/p613/hyprland-test.lua
    cp /project/native/p613-desktop-proof /target/usr/local/bin/p613-desktop-proof
    chmod 755 /target/usr/local/bin/p613-desktop-proof
    ln -sfn /usr/share/zoneinfo/America/Phoenix /target/etc/localtime
    chroot /target /usr/bin/Hyprland --version
    mkdir -p /target/tmp/p613-verify
    chown 1000:1000 /target/tmp/p613-verify
    chmod 700 /target/tmp/p613-verify
    chroot /target /usr/bin/runuser -u omarchy -- /usr/bin/env XDG_RUNTIME_DIR=/tmp/p613-verify \
      /usr/bin/Hyprland --verify-config --config /etc/p613/hyprland-test.lua
    for lib in libgallium-26.2.0-devel.so libvulkan_freedreno.so; do
      deps=$(chroot /target /usr/bin/env LD_LIBRARY_PATH=/opt/p613-gpu/lib /usr/bin/ldd "/opt/p613-gpu/lib/$lib")
      echo "$deps"
      if grep -q 'not found' <<< "$deps"; then echo 'Missing graphics dependency' >&2; exit 1; fi
    done
  fi
  ;;
inspect)
  chroot /target /bin/bash -c 'pacman -Q; ldd --version | head -1'
  ;;
*) echo 'Unknown rootfs mode' >&2; exit 2;;
esac
sync
