#!/usr/bin/env python3
"""Stage hash-pinned private DBMDX firmware in the native RAM system only."""
import hashlib
import json
from pathlib import Path
import shlex
import subprocess

root = Path(__file__).resolve().parent.parent
source = root/'work/hardware-test-10/firmware-source/vendor-files/firmware'
items = json.loads((root/'docs/build-records/power-firmware.json').read_text())['files']
assert {item['path'] for item in items} == {'dbmd8_va_fw.bin', 'dbmd8_va_asrp_fw.bin'}
ssh = ['ssh', '-T', '-i', str(root/'work/keys/client_ed25519'),
       '-o', 'UserKnownHostsFile='+str(root/'work/keys/tablet_known_hosts'),
       '-o', 'StrictHostKeyChecking=yes', '-o', 'BatchMode=yes',
       '-o', 'ConnectTimeout=8', '-o', 'ServerAliveInterval=3',
       '-o', 'ServerAliveCountMax=2', 'root@192.168.77.1']

def run(command, data=None):
    result = subprocess.run(ssh+[command], input=data, capture_output=True, timeout=30)
    if result.returncode:
        raise RuntimeError(result.stderr.decode(errors='replace'))
    return result.stdout.decode()

run('''set -eu
test "$(uname -r)" = 4.14.357-openela-perf-g21b136df1533
test -f /bringup.log
test ! -e /run/arch-root-mounted
mkdir -p /lib/firmware /vendor/firmware_mnt/image
''')
# Check every input before writing any of them. Blobs stay outside Git.
for item in items:
    file = source/item['path']
    assert file.stat().st_size == item['bytes']
    assert hashlib.sha256(file.read_bytes()).hexdigest() == item['sha256']
for item in items:
    name = item['path']
    staged = '/lib/firmware/.'+name+'.p613-staged'
    dest = '/lib/firmware/'+name
    vendor = '/vendor/firmware_mnt/image/'+name
    command = f'''set -eu
cat > {shlex.quote(staged)}
mv {shlex.quote(staged)} {shlex.quote(dest)}
cp {shlex.quote(dest)} {shlex.quote(vendor+'.p613-staged')}
mv {shlex.quote(vendor+'.p613-staged')} {shlex.quote(vendor)}
sha256sum {shlex.quote(dest)}
'''
    actual = run(command, (source/name).read_bytes()).split()[0]
    assert actual == item['sha256']
    print('POWER_FIRMWARE_STAGED', name, flush=True)
# Complete an already-pending fallback with the standard firmware-loader API.
# Future requests find the complete files through ordinary firmware lookup.
print(run('''set -eu
request=/sys/class/firmware/dbmd8_va_fw.bin
if [ -d "$request" ]; then
    test "$(readlink -f "$request")" = /sys/devices/platform/soc/soc:dbmdx/firmware/dbmd8_va_fw.bin
    echo 1 > "$request/loading"
    cat /lib/firmware/dbmd8_va_fw.bin > "$request/data"
    echo 0 > "$request/loading"
    echo PENDING_DBMDX_REQUEST_COMPLETED
else
    echo NO_PENDING_DBMDX_REQUEST
fi
''').strip())
