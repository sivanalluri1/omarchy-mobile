#!/usr/bin/env python3
"""Stage the tested temporary connection runtime and tablet password prompt.

Requires the private extracted Debian packages retained by hardware test 10.
No password is accepted by this script. It neither starts a connection nor
changes the immutable Arch image.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shlex
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--ssid', required=True)
a = p.parse_args()
assert 1 <= len(a.ssid.encode()) <= 32 and all(ord(c) >= 32 for c in a.ssid)
root = Path(__file__).resolve().parent.parent
private = root/'work/hardware-test-10'
metadata = json.loads((root/'docs/build-records/wifi-connection-runtime.json').read_text())
ssh = ['ssh', '-T', '-i', str(root/'work/keys/client_ed25519'),
       '-o', 'UserKnownHostsFile='+str(root/'work/keys/tablet_known_hosts'),
       '-o', 'StrictHostKeyChecking=yes', '-o', 'BatchMode=yes',
       '-o', 'ConnectTimeout=10', '-o', 'ServerAliveInterval=3',
       '-o', 'ServerAliveCountMax=2', 'root@192.168.77.1']


def run(command, **kwargs):
    return subprocess.run(ssh+[command], check=True, timeout=45, **kwargs)


preflight = run('test -f /run/arch-root-mounted && test -f /run/p613-radio-active && '
                'test ! -f /arch/run/p613-wpa.pid && sha256sum /dev/sda19',
                capture_output=True, text=True)
assert preflight.stdout.split()[0] == 'e6585dfd5a81025f3848e6a2cee20d4b5914a929b0153758365a4c964a74fbc6'
run('mkdir -p /arch/tmp/p613-wpa-libs /arch/home/omarchy/.local/share/applications')
assets = [(private/item['source'], item['target'], item['mode'], item['sha256'])
          for item in metadata['assets']]
assets += [(root/'native'/name, target, mode, None) for name, target, mode in [
    ('p613-wifi-test.py', '/arch/tmp/p613-wifi-test.py', '755'),
    ('connect-p613-wpa.py', '/arch/tmp/connect-p613-wpa.py', '700'),
    ('p613-udhcpc.sh', '/tmp/p613-udhcpc.sh', '700'),
    ('watch-p613-wpa.sh', '/tmp/watch-p613-wpa.sh', '700')]]
for source, target, mode, expected in assets:
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    assert expected is None or digest == expected
    with source.open('rb') as stream:
        run('set -e; cat >'+shlex.quote(target)+'; chmod '+mode+' '+shlex.quote(target), stdin=stream)
    actual = run('sha256sum '+shlex.quote(target), capture_output=True, text=True).stdout.split()[0]
    assert actual == digest
quoted_ssid = '"'+a.ssid.replace('\\', '\\\\').replace('"', '\\"').replace('$', '\\$').replace('`', '\\`').replace('%', '%%')+'"'
desktop = ('[Desktop Entry]\nType=Application\nName=Wi-Fi Connection Test\n'
           'Exec=/usr/bin/python /tmp/p613-wifi-test.py --ssid '+quoted_ssid+'\n'
           'Icon=network-wireless\nTerminal=false\nCategories=Utility;\n')
run('cat >/arch/home/omarchy/.local/share/applications/p613-wifi-test.desktop; '
    'chown -R 1000:1000 /arch/home/omarchy/.local/share', input=desktop, text=True)
run('chroot /arch /usr/bin/runuser -u omarchy -- /usr/bin/env XDG_RUNTIME_DIR=/run/user/1000 '
    '/usr/bin/hyprctl -i 0 dispatch "hl.dsp.exec_cmd([[omamobile-launch app p613-wifi-test]])"')
print('Password prompt opened on the tablet; no password received by the host')
