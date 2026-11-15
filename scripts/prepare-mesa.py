#!/usr/bin/env python3
"""Fetch immutable Mesa archive and extract into case-sensitive SSD storage."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile

root = Path(__file__).resolve().parent.parent
lock = json.loads((root / 'mesa.lock.json').read_text())
if len(sys.argv) != 2:
    sys.exit('Usage: prepare-mesa.py /Volumes/OmarchyBuild')
base = Path(sys.argv[1]).resolve()
if not (base / '.omarchy-storage').is_file():
    sys.exit('Configured case-sensitive SSD mount is required')
archive = root / 'work/graphics/mesa-source.tar.gz'
archive.parent.mkdir(parents=True, exist_ok=True)
if not archive.exists():
    partial = archive.with_suffix('.partial')
    subprocess.run(['curl', '-fL', '--retry', '2', '--max-time', '300',
                    lock['archive_url'], '-o', str(partial)], check=True)
    partial.rename(archive)
h = hashlib.sha256()
with archive.open('rb') as stream:
    for block in iter(lambda: stream.read(1024 * 1024), b''):
        h.update(block)
if h.hexdigest() != lock['archive_sha256']:
    sys.exit('Archive hash mismatch')
source = base / 'checkout/mesa-turnip'
if source.exists():
    # Verify every regular file against the trusted archive, including any accidental edits.
    with tarfile.open(archive) as tar:
        for member in tar:
            name = Path(member.name)
            if name.is_absolute() or '..' in name.parts:
                sys.exit('Unsafe archive path')
            if member.isfile():
                path = source / member.name
                if not path.is_file() or path.is_symlink():
                    sys.exit(f'Missing/unsafe source: {member.name}')
                if path.read_bytes() != tar.extractfile(member).read():
                    sys.exit(f'Modified source: {member.name}')
            elif member.issym():
                if not (source / member.name).is_symlink() or os.readlink(source / member.name) != member.linkname:
                    sys.exit(f'Modified source symlink: {member.name}')
    print('Existing source files match pinned archive')
else:
    source.mkdir(parents=True)
    subprocess.run(['tar', '-xzf', str(archive), '-C', str(source)], check=True)
print(f'Mesa {lock["revision"]}; archive SHA256 {h.hexdigest()}')
