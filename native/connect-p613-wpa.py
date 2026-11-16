#!/usr/bin/env python3
"""Consume the tablet GUI's RAM-only WPA2 request and check authentication."""
import argparse
import json
import os
from pathlib import Path
import re
import signal
import stat
import subprocess
import time

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--ssid', required=True)
a = p.parse_args()
assert os.getuid() == 0
assert os.uname().release == '4.14.357-openela-perf-g21b136df1533'
assert Path('/etc/p613-bringup').is_file()
state = Path('/home/omarchy/.local/state/p613-wifi')
request = state/'request.conf'
info = request.lstat()
assert stat.S_ISREG(info.st_mode) and info.st_uid == 1000
assert stat.S_IMODE(info.st_mode) == 0o600 and info.st_size < 1024
text = request.read_text()
ssid = re.search(r'^\s*ssid=([0-9a-f]+)$', text, re.M)
psk = re.search(r'^\s*psk=([0-9a-f]{64})$', text, re.M)
assert ssid and psk and bytes.fromhex(ssid[1]) == a.ssid.encode()
config = Path('/tmp/p613-wpa.conf')
fd = os.open(config, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, 'w') as out:
    out.write('ctrl_interface=/run/p613-wpa\nupdate_config=0\nnetwork={\n')
    out.write(f'    ssid={ssid[1]}\n    psk={psk[1]}\n')
    out.write('    key_mgmt=WPA-PSK\n    proto=RSN\n    pairwise=CCMP\n    group=CCMP\n}\n')
request.unlink()
text = psk = None
env = dict(os.environ, LD_LIBRARY_PATH='/tmp/p613-wpa-libs')
started = False
try:
    subprocess.run(['/tmp/wpa_supplicant', '-B', '-Dnl80211', '-iwlan0',
                    '-c'+str(config), '-P/run/p613-wpa.pid', '-f/tmp/p613-wpa.log'],
                   env=env, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    started = True
    for _ in range(45):
        result = subprocess.run(['/tmp/wpa_cli', '-p/run/p613-wpa', '-iwlan0', 'status'],
                                env=env, capture_output=True, text=True, check=True)
        status = dict(line.split('=', 1) for line in result.stdout.splitlines() if '=' in line)
        if status.get('wpa_state') == 'COMPLETED':
            print('P613_WPA_AUTHENTICATED')
            break
        time.sleep(1)
    else:
        raise RuntimeError('WPA authentication did not complete')
except Exception:
    if started:
        pidfile = Path('/run/p613-wpa.pid')
        if pidfile.exists():
            pid = int(pidfile.read_text())
            if Path(f'/proc/{pid}/comm').read_text().strip() == 'wpa_supplicant':
                os.kill(pid, signal.SIGTERM)
            pidfile.unlink(missing_ok=True)
    (state/'status.json').write_text(json.dumps({'state': 'failed'})+'\n')
    raise
finally:
    config.unlink(missing_ok=True)
