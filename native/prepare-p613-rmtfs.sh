#!/bin/sh
# Copy verified modem partitions to RAM; never open original storage writable.
set -eu
[ "$(uname -r)" = 4.14.357-openela-perf-g21b136df1533 ]
grep -q 'Samsung GTA4XLVE EUR PROJECT BRINGUP' /proc/device-tree/model
[ -f /run/arch-root-mounted ]
[ "$(cat /sys/class/uio/uio0/name)" = rmtfs ]
[ -x /arch/tmp/rmtfs-daemon ]
[ ! -e /arch/tmp/rmtfs ]
mkdir -m 700 /arch/tmp/rmtfs
for mapping in sda1:modemst1:modem_fs1 sda2:modemst2:modem_fs2 sdf1:fsg:modem_fsg sda3:fsc:modem_fsc; do
    node=${mapping%%:*}
    rest=${mapping#*:}
    label=${rest%%:*}
    file=${rest#*:}
    grep -qx "PARTNAME=$label" "/sys/class/block/$node/uevent"
    [ -b "/dev/$node" ]
    dd if="/dev/$node" of="/arch/tmp/rmtfs/$file" bs=1M
    cmp "/dev/$node" "/arch/tmp/rmtfs/$file"
done
ln -sf /dev/uio0 /dev/qcom_rmtfs_uio1
chroot /arch /usr/bin/env LD_LIBRARY_PATH=/opt/p613-compat/lib \
    /tmp/rmtfs-daemon -r -o /tmp/rmtfs -v >/arch/tmp/rmtfs.log 2>&1 </dev/null &
echo $! >/run/p613-rmtfs.pid
