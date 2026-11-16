#!/usr/bin/env python3
"""Generate four ephemeral locally administered WLAN addresses in RAM.

Avoid the optional firmware-file timeout and serial-derived fallback. This
does not read or replace the tablet's factory MAC/NV storage.
"""
import os
from pathlib import Path
import secrets

assert os.geteuid() == 0
assert os.uname().release == '4.14.357-openela-perf-g21b136df1533'
assert Path('/etc/p613-bringup').is_file()
addresses = set()
while len(addresses) < 4:
    addresses.add(b'\x02' + secrets.token_bytes(5))
contents = ''.join(f'Intf{i}MacAddress={mac.hex().upper()}\n'
                   for i, mac in enumerate(sorted(addresses))) + 'END\n'
path = Path('/tmp/p613-wlan-mac.bin')
path.write_text(contents)
path.chmod(0o600)
print('Prepared four private RAM-only locally administered WLAN addresses')
