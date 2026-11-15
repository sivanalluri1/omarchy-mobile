#!/usr/bin/env python3
"""Fetch pinned Weston and apply/verify the scoped downstream DRM compatibility patch."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tarfile

root=Path(__file__).resolve().parent.parent
lock=json.loads((root/'weston.lock.json').read_text())
if len(sys.argv)!=2:
    sys.exit('Usage: prepare-weston.py /Volumes/OmarchyBuild')
base=Path(sys.argv[1]).resolve()
if not (base/'.omarchy-storage').is_file():
    sys.exit('Configured case-sensitive SSD mount is required')
def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda:stream.read(1024*1024),b''):
            h.update(block)
    return h.hexdigest()
archive=root/'work/graphics/weston-14.0.2.tar.xz'
archive.parent.mkdir(parents=True,exist_ok=True)
if not archive.exists():
    partial=archive.with_suffix('.partial')
    subprocess.run(['curl','-fL','--retry','2','--max-time','120',lock['archive_url'],'-o',str(partial)],check=True)
    if digest(partial)!=lock['archive_sha256']:
        sys.exit('Downloaded Weston archive hash mismatch')
    partial.rename(archive)
if digest(archive)!=lock['archive_sha256']:
    sys.exit('Weston archive hash mismatch')
for patch,expected in lock['patch_sha256'].items():
    if digest(root/patch)!=expected:
        sys.exit(f'Patch hash mismatch: {patch}')
source=base/'checkout/weston'
if not source.exists():
    source.mkdir(parents=True)
    subprocess.run(['tar','-xJf',str(archive),'-C',str(source),'--strip-components=1'],check=True)
    for patch in lock['patches']:
        subprocess.run(['patch','-p1','--batch','--forward','-i',str(root/patch)],cwd=source,check=True)
with tarfile.open(archive) as tar:
    for member in tar:
        if not member.isfile():
            continue
        name=Path(*Path(member.name).parts[1:])
        path=source/name
        if path.is_symlink() or not path.is_file():
            sys.exit(f'Missing/unsafe Weston source: {name}')
        if str(name) in lock['patched_files']:
            if digest(path)!=lock['patched_files'][str(name)]:
                sys.exit(f'Patched Weston source mismatch: {name}')
        elif path.read_bytes()!=tar.extractfile(member).read():
            sys.exit(f'Modified Weston source: {name}')
print(f'Weston {lock["version"]}: source and scoped DRM patch verified')
