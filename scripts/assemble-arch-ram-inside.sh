#!/usr/bin/env bash
# Prepare a cloned developer image, never the original or a physical disk.
set -euo pipefail
mknod /dev/loop-control c 10 237
for n in $(seq 0 63); do mknod "/dev/loop$n" b 7 "$n"; done
loop=$(losetup --find --show /out/arch-ram.img)
mkdir -p /target
cleanup() {
  if mountpoint -q /target; then
    if [ -c /target/dev/null ]; then chroot /target /usr/bin/gpgconf --homedir /etc/pacman.d/gnupg --kill all || true; fi
    umount -R /target || { losetup -d "$loop"; return 1; }
  fi
  losetup -d "$loop"
}
trap cleanup EXIT
mount "$loop" /target
mount --rbind /dev /target/dev
mount --make-rslave /target/dev
mount -t proc proc /target/proc
chroot /target /bin/bash -s <<'ARCH'
set -euo pipefail
# Generic PC/GPU firmware is not used by the Samsung vendor-kernel experiment.
mapfile -t firmware_packages < <(pacman -Qq | grep '^linux-firmware' || true)
if [ "${#firmware_packages[@]}" -gt 0 ]; then pacman -Rdd --noconfirm "${firmware_packages[@]}"; fi
# This is the disposable clone; retain the original image/cache separately.
find /var/cache/pacman/pkg -mindepth 1 -maxdepth 1 -type f -delete
ARCH
python3 - <<'PY'
from pathlib import Path
import hashlib,json,shutil
manifest=json.loads(Path('/project/docs/build-records/graphics-firmware.json').read_text())
for item in manifest:
    source=Path('/firmware')/item['name']
    assert hashlib.sha256(source.read_bytes()).hexdigest()==item['sha256']
    for directory in ['usr/lib/firmware','vendor/firmware_mnt/image']:
        dest=Path('/target')/directory/source.name
        dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(source,dest)
PY
cp /project/native/p613-desktop-proof /target/usr/local/bin/p613-desktop-proof
chmod 755 /target/usr/local/bin/p613-desktop-proof
chroot /target /usr/bin/pacman -Q > /out/package-versions.txt
chroot /target /usr/bin/gpgconf --homedir /etc/pacman.d/gnupg --kill all || true
sleep 1
umount /target/proc
umount -R /target/dev
sync
mksquashfs /target /out/arch-root.squashfs -noappend -comp xz -b 1048576 \
  -processors 4 -no-progress -wildcards -e 'dev/*' 'proc/*' 'sys/*' 'run/*' 'tmp/*'
unsquashfs -s /out/arch-root.squashfs
python3 - <<'PY'
import hashlib,json
from pathlib import Path
p=Path('/out/arch-root.squashfs')
assert p.stat().st_size < 768*1024*1024, 'RAM image exceeds 768 MiB budget'
h=hashlib.sha256()
with p.open('rb') as stream:
    for b in iter(lambda:stream.read(1024*1024),b''): h.update(b)
r={'bytes':p.stat().st_size,'sha256':h.hexdigest(),'compression':'xz','block_size':1048576,
   'generic_firmware_packages_removed':True,'package_cache_removed':True,
   'device_firmware_validated_and_included':True,'metadata_preserved':True,'tablet_tested':False}
Path('/out/validation.json').write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps(r,indent=2))
PY
