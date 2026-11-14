#!/usr/bin/env python3
"""Read four fixed boot partitions over USB ADB using an existing root installation.

No writes to the tablet, root installation, reboot or flash operations.
Raw backups stay under ignored work/device-backups. Requires device authorization.
"""
import hashlib
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
out = root / 'work/device-backups'
out.mkdir(parents=True, exist_ok=True, mode=0o700)

def shell(command):
    return subprocess.check_output(['adb', '-d', 'shell', command], text=True).strip()

if shell('getprop ro.product.model') != 'SM-P613':
    raise SystemExit('Expected USB-connected SM-P613')
if 'uid=0(' not in shell("timeout 15 su -c 'id'"):
    raise SystemExit('Existing root access required; no root installation attempted')
records = []
for name in ['boot', 'recovery', 'dtbo', 'vbmeta']:
    device = '/dev/block/bootdevice/by-name/' + name
    size = int(shell(f"su -c 'blockdev --getsize64 {device}'"))
    if not 0 < size <= 128 * 1024 * 1024:
        raise SystemExit(f'Unexpected partition size: {name}')
    path = out / (name + '.img')
    temporary = out / (name + '.img.part')
    if path.exists():
        raise SystemExit(f'Backup already exists; preserve it before a new capture: {path}')
    with temporary.open('xb') as stream:
        subprocess.run(['adb', '-d', 'exec-out', f"su -c 'cat {device}'"], stdout=stream, check=True)
    if temporary.stat().st_size != size:
        raise SystemExit(f'Backup size mismatch: {name}')
    sha = hashlib.sha256()
    with temporary.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            sha.update(chunk)
    if sha.hexdigest() != shell(f"su -c 'sha256sum {device}'").split()[0]:
        raise SystemExit(f'Backup digest mismatch: {name}')
    temporary.replace(path)
    records.append({'partition': name, 'bytes': size, 'sha256': sha.hexdigest(), 'device_hash_matches': True})
    print(f'Verified backup: {name}')
(out / 'capture-inventory.json').write_text(json.dumps(records, indent=2) + '\n')
