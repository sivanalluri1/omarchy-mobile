#!/bin/bash
# Run in an isolated ARM64 container. /rootfs is ephemeral Linux storage.
set -euo pipefail
mkdir -p /rootfs/{bin,sbin,usr/sbin,usr/bin,etc/dropbear,root/.ssh,dev/pts,proc,sys,run,tmp,lib}
cp /bin/busybox /rootfs/bin/busybox
chroot /rootfs /bin/busybox --install -s /bin
cp /usr/sbin/dropbear /rootfs/usr/sbin/dropbear
python3 - <<'PY'
import re,subprocess,shutil
from pathlib import Path
for source in re.findall(r'/[^\s()]+',subprocess.check_output(['ldd','/usr/sbin/dropbear'],text=True)):
    path=Path(source)
    if path.is_file():
        target=Path('/rootfs')/path.relative_to('/')
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(path,target)
PY
cp /project-init/init /rootfs/init
chmod 755 /rootfs/init
printf 'root::0:0:root:/root:/bin/sh\n' > /rootfs/etc/passwd
printf 'root:x:0:\n' > /rootfs/etc/group
printf '/bin/sh\n' > /rootfs/etc/shells
printf 'p613-linux\n' > /rootfs/etc/hostname
printf '127.0.0.1 localhost p613-linux\n' > /rootfs/etc/hosts
cp /keys/client_ed25519.pub /rootfs/root/.ssh/authorized_keys
chmod 700 /rootfs/root /rootfs/root/.ssh
chmod 600 /rootfs/root/.ssh/authorized_keys
if [ ! -f /keys/dropbear_ed25519_host_key ]; then
  dropbearkey -t ed25519 -f /keys/dropbear_ed25519_host_key >/dev/null
fi
cp /keys/dropbear_ed25519_host_key /rootfs/etc/dropbear/
chmod 600 /rootfs/etc/dropbear/dropbear_ed25519_host_key
mknod /rootfs/dev/console c 5 1
mknod /rootfs/dev/null c 1 3
mknod /rootfs/dev/zero c 1 5
mknod /rootfs/dev/random c 1 8
mknod /rootfs/dev/urandom c 1 9
chmod 600 /rootfs/dev/console
chmod 666 /rootfs/dev/{null,zero,random,urandom}
chroot /rootfs /bin/sh -n /init
chroot /rootfs /bin/busybox true
# Exercise the actual rootfs SSH server over container loopback with no network access.
chroot /rootfs /usr/sbin/dropbear -F -E -s -j -k \
  -r /etc/dropbear/dropbear_ed25519_host_key -p 127.0.0.1:2222 > /out/ssh-selftest.log 2>&1 &
server=$!
trap 'kill "$server" 2>/dev/null || true' EXIT
sleep 1
result=$(ssh -T -i /keys/client_ed25519 -p 2222 \
  -o BatchMode=yes -o PreferredAuthentications=publickey \
  -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/out/test_known_hosts \
  root@127.0.0.1 'echo p613-rootfs-ssh-ready')
[ "$result" = p613-rootfs-ssh-ready ]
kill "$server"
wait "$server" || true
trap - EXIT
# Fixed archive metadata; keys are generated once per project and remain private.
find /rootfs -exec touch -h -d @0 {} +
(cd /rootfs && find . -print0 | LC_ALL=C sort -z | cpio --null -o --format=newc --owner=0:0 --quiet | gzip -n -9 > /out/initramfs.cpio.gz)
gzip -t /out/initramfs.cpio.gz
sha256sum /out/initramfs.cpio.gz > /out/initramfs.sha256
printf 'Chroot shell check, native busybox and public-key SSH self-test passed.\n'
dpkg-query -W busybox-static dropbear-bin libc6 > /out/packages.txt
