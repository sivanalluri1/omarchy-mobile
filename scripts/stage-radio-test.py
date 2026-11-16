#!/usr/bin/env python3
"""Stage private radio firmware/tools into the native RAM experiment over SSH.

Does not boot subsystems, start Wi-Fi, mount Android storage, flash or reboot.
"""
import hashlib
import json
from pathlib import Path
import shlex
import subprocess

root = Path(__file__).resolve().parent.parent
settings = dict(line.split('=', 1) for line in (root/'storage.local.env').read_text().splitlines()
                if line and not line.startswith('#'))
build = Path(settings['OMARCHY_LINUX_ROOT'])/'build/radio-tools'
evidence = root/'work/hardware-test-10'
ssh = ['ssh', '-T', '-i', str(root/'work/keys/client_ed25519'),
       '-o', 'UserKnownHostsFile='+str(root/'work/keys/tablet_known_hosts'),
       '-o', 'StrictHostKeyChecking=yes', '-o', 'BatchMode=yes',
       '-o', 'ConnectTimeout=10', '-o', 'ServerAliveInterval=3',
       '-o', 'ServerAliveCountMax=2', 'root@192.168.77.1']


def run(command, **kwargs):
    return subprocess.run(ssh+[command], check=True, timeout=180, **kwargs)


boot = run('test -f /run/arch-root-mounted && sha256sum /dev/sda19', capture_output=True, text=True)
assert boot.stdout.split()[0] == 'e6585dfd5a81025f3848e6a2cee20d4b5914a929b0153758365a4c964a74fbc6'
files = []
for name in ['radio', 'modem']:
    manifest = json.loads((evidence/(name+'-firmware-manifest.json')).read_text())
    for item in manifest:
        path = Path(item['path'])
        assert not path.is_absolute() and '..' not in path.parts
    with (evidence/(name+'-firmware.tar.gz')).open('rb') as stream:
        run('tar -xzf - -C /vendor/firmware_mnt/image', stdin=stream)
    files += manifest
checks = ''.join(item['sha256']+'  /vendor/firmware_mnt/image/'+item['path']+'\n' for item in files)
result = run('sha256sum -c -', input=checks, capture_output=True, text=True)
(evidence/'clean-firmware-device-verification.txt').write_text(result.stdout)
for source, target in [
    *[(build/name, '/tmp/'+name) for name in ['qrtr-ns', 'qrtr-lookup', 'pd-mapper', 'tqftpserv']],
    (build/'rmtfs', '/arch/tmp/rmtfs-daemon'),
    (root/'native/start-p613-radio.sh', '/tmp/start-p613-radio.sh'),
    (root/'native/prepare-p613-rmtfs.sh', '/tmp/prepare-p613-rmtfs.sh'),
    (root/'native/run-p613-radio-test.sh', '/tmp/run-p613-radio-test.sh'),
    (root/'native/prepare-p613-wlan-mac.py', '/arch/tmp/prepare-p613-wlan-mac.py'),
    (root/'native/p613-wlfw-init.py', '/arch/tmp/p613-wlfw-init.py')]:
    with source.open('rb') as stream:
        run('set -e; cat >'+shlex.quote(target)+'; chmod 700 '+shlex.quote(target), stdin=stream)
    actual = run('sha256sum '+shlex.quote(target), text=True, capture_output=True).stdout.split()[0]
    assert actual == hashlib.sha256(source.read_bytes()).hexdigest()
run('cp /vendor/firmware_mnt/image/wlan/qca_cld/bdwlan.bin /arch/tmp/p613-bdwlan.bin; mkdir -p /var/lib/tqftpserv')
print(f'Verified {len(files)} firmware files and staged tools; no radio started')
