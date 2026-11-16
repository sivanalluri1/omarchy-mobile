#!/usr/bin/env python3
"""Use the hash-verified mounted image's packaged radio payload in native RAM."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
ssh = ['ssh', '-T', '-i', str(root/'work/keys/client_ed25519'),
       '-o', 'UserKnownHostsFile='+str(root/'work/keys/tablet_known_hosts'),
       '-o', 'StrictHostKeyChecking=yes', '-o', 'BatchMode=yes',
       '-o', 'ConnectTimeout=10', '-o', 'ServerAliveInterval=3',
       '-o', 'ServerAliveCountMax=2', 'root@192.168.77.1']
command = '''set -eu
test -f /run/arch-root-mounted
test "$(uname -r)" = 4.14.357-openela-perf-g21b136df1533
test -d /arch/opt/p613-firmware
test ! -e /run/p613-radio-active
cp -a /arch/opt/p613-firmware/. /vendor/firmware_mnt/image/
for name in qrtr-ns qrtr-lookup pd-mapper tqftpserv start-p613-radio.sh prepare-p613-rmtfs.sh run-p613-radio-test.sh; do
    cp /arch/usr/local/libexec/p613/radio/$name /tmp/$name
    chmod 700 /tmp/$name
done
cp /arch/usr/local/libexec/p613/radio/rmtfs /arch/tmp/rmtfs-daemon
chmod 700 /arch/tmp/rmtfs-daemon
for name in prepare-p613-wlan-mac.py p613-wlfw-init.py; do
    cp /arch/usr/local/libexec/p613/radio/$name /arch/tmp/$name
done
cp /arch/opt/p613-firmware/wlan/qca_cld/bdwlan.bin /arch/tmp/p613-bdwlan.bin
mkdir -p /var/lib/tqftpserv
echo PACKAGED_RADIO_STAGED
'''
subprocess.run(ssh+[command], check=True, timeout=60)
