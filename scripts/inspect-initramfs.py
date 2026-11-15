#!/usr/bin/env python3
"""Inspect a generated gzip/newc archive without extracting private keys."""
import gzip
import hashlib
import json
from pathlib import Path
import stat
import sys

path = Path(sys.argv[1])
blob = path.read_bytes()
data = gzip.decompress(blob)
pos = 0
entries = {}
while pos + 110 <= len(data):
    header = data[pos:pos + 110]
    if header[:6] not in (b'070701', b'070702'):
        raise SystemExit('Invalid CPIO header')
    mode, uid, gid = (int(header[a:a + 8], 16) for a in (14, 22, 30))
    size, namesize = int(header[54:62], 16), int(header[94:102], 16)
    name = data[pos + 110:pos + 110 + namesize - 1].decode()
    start = (pos + 110 + namesize + 3) // 4 * 4
    if start + size > len(data):
        raise SystemExit('Truncated CPIO payload')
    if name == 'TRAILER!!!':
        break
    if name.startswith('./'):
        name = name[2:]
    if uid or gid:
        raise SystemExit('Non-root CPIO ownership')
    entries[name] = {'mode': mode, 'bytes': size}
    pos = (start + size + 3) // 4 * 4
else:
    raise SystemExit('CPIO trailer missing')
for name in ('init', 'bin/busybox', 'usr/sbin/dropbear', 'root/.ssh/authorized_keys', 'dev/console'):
    if name not in entries:
        raise SystemExit(f'Missing {name}')
if not entries['init']['mode'] & 0o111 or not stat.S_ISCHR(entries['dev/console']['mode']):
    raise SystemExit('Invalid init mode or console device')
if any('client_ed25519' in name for name in entries):
    raise SystemExit('Client private key leaked into archive')
print(json.dumps({'archive_bytes': len(blob), 'archive_sha256': hashlib.sha256(blob).hexdigest(),
                  'cpio_entries': len(entries), 'all_entries_uid_gid_zero': True,
                  'init_executable': True, 'console_device_node_present': True,
                  'client_private_key_excluded': True}, indent=2))
