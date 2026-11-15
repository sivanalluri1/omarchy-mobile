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
    if [ -x /target/usr/bin/gpgconf ]; then
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
packages)
  printf 'Server = https://fl.us.mirror.archlinuxarm.org/$arch/$repo\n' > /target/etc/pacman.d/mirrorlist
  cp --remove-destination /etc/resolv.conf /target/etc/resolv.conf
  mount -t proc proc /target/proc
  mount --rbind /dev /target/dev
  mount --make-rslave /target/dev
  mount -t sysfs -o ro sysfs /target/sys
  chroot /target /bin/bash -s < /project/scripts/configure-arch-inside.sh
  ;;
inspect)
  chroot /target /bin/bash -c 'pacman -Q; ldd --version | head -1'
  ;;
*) echo 'Unknown rootfs mode' >&2; exit 2;;
esac
sync
