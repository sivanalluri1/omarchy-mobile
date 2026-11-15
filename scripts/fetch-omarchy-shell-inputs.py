#!/usr/bin/env python3
"""Fetch pinned inputs over verified HTTPS; build verifies package signatures."""
import hashlib
import json
from pathlib import Path
import urllib.request

root=Path(__file__).resolve().parent.parent
lock=json.loads((root/'omarchy-shell.lock.json').read_text())
mobile=json.loads((root/'userspace.lock.json').read_text())['upstream_omarchy_mobile']
output=root/'work/omarchy-integration'
output.mkdir(parents=True,exist_ok=True)
def fetch(url,name,digest=None):
    dest=output/name
    if dest.is_file() and digest and hashlib.sha256(dest.read_bytes()).hexdigest()==digest:
        return
    temp=dest.with_name(dest.name+'.partial')
    with urllib.request.urlopen(url,timeout=60) as response, temp.open('wb') as stream:
        while block:=response.read(1024*1024):
            stream.write(block)
    if digest and hashlib.sha256(temp.read_bytes()).hexdigest()!=digest:
        temp.unlink()
        raise ValueError('SHA256 mismatch: '+name)
    temp.replace(dest)
for name in ['omarchy','quickshell','keyring']:
    entry=lock[name]
    fetch(entry['url'],name+'.pkg.tar.zst',entry['sha256'])
    if name!='keyring':
        fetch(entry['url']+'.sig',name+'.pkg.tar.zst.sig')
fetch('https://github.com/derekross/omarchy-mobile/archive/'+mobile['revision']+'.tar.gz',
      'mobile-source.tar.gz',mobile['archive_sha256'])
fetch('https://raw.githubusercontent.com/omacom/omarchy/v4.5.0/LICENSE',
      'omarchy-LICENSE','717ba1949502290f8e47688ae2e323acd06c8ca47aec9f7596b15f678c1af4a2')
print('Pinned shell inputs ready; detached signatures are checked inside the build')
