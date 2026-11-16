#!/usr/bin/env python3
"""Hash-check and package private tablet firmware and radio helpers offline."""
import hashlib
import json
from pathlib import Path
import shutil

project = Path('/project')
target = Path('/target')
inputs = Path('/radio-inputs')
firmware = target/'opt/p613-firmware'
for manifest, source in [
    (json.loads((project/'docs/build-records/radio-firmware.json').read_text())['files'], inputs/'radio-firmware'),
    (json.loads((inputs/'modem-firmware-manifest.json').read_text()), inputs/'firmware-source/modem-files')]:
    for item in manifest:
        relative = Path(item['path'])
        assert not relative.is_absolute() and '..' not in relative.parts
        file = source/relative
        assert hashlib.sha256(file.read_bytes()).hexdigest() == item['sha256']
        dest = firmware/relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(file, dest)
for item in json.loads((project/'docs/build-records/radio-tools-build.json').read_text())['binaries']:
    source = Path('/radio-tools')/item['name']
    assert hashlib.sha256(source.read_bytes()).hexdigest() == item['sha256']
    dest = target/'usr/local/libexec/p613/radio'/item['name']
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, dest)
for name in ['start-p613-radio.sh', 'prepare-p613-rmtfs.sh', 'run-p613-radio-test.sh',
             'prepare-p613-wlan-mac.py', 'p613-wlfw-init.py']:
    dest = target/'usr/local/libexec/p613/radio'/name
    shutil.copy2(project/'native'/name, dest)
    dest.chmod(0o755)
print('PACKAGED_HASH_VERIFIED_PRIVATE_RADIO_PAYLOAD')
