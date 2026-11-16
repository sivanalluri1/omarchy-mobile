#!/usr/bin/env python3
"""Stage hash-pinned shell data in the disposable Linux image only."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tarfile

project=Path('/project')
target=Path('/target')
lock=json.loads((project/'omarchy-shell.lock.json').read_text())
for name in ['omarchy','quickshell','keyring','settings']:
    source=Path('/inputs')/(name+'.pkg.tar.zst')
    with source.open('rb') as stream:
        assert hashlib.file_digest(stream,'sha256').hexdigest()==lock[name]['sha256'],name
# Extract the verified keyring again rather than trust a previous unpacked copy.
subprocess.run(['bsdtar','-xf','/inputs/keyring.pkg.tar.zst','-C','/tmp'],check=True)
# Data-only extraction: do not run the complete Omarchy installer or package hooks.
subprocess.run(['bsdtar','-xf','/inputs/omarchy.pkg.tar.zst','-C',str(target),
                'usr/share/omarchy','usr/bin'],check=True)
subprocess.run(['bsdtar','-xf','/inputs/settings.pkg.tar.zst','-C',str(target),'usr/share/omarchy'],check=True)
metadata=json.loads((project/'docs/build-records/wayland-build.json').read_text())
runtime=Path('/runtime')
assert hashlib.sha256((runtime/'manifest.json').read_bytes()).hexdigest()==metadata['runtime_manifest_sha256']
entry=next(e for e in json.loads((runtime/'manifest.json').read_text()) if e['path']=='gpu/lib/libudev.so.1')
source=runtime/entry['path']
assert hashlib.sha256(source.read_bytes()).hexdigest()==entry['sha256']
dest=target/'opt/p613-compat/lib/libudev.so.1'
dest.parent.mkdir(parents=True,exist_ok=True)
shutil.copy2(source,dest)
pin=json.loads((project/'userspace.lock.json').read_text())['upstream_omarchy_mobile']
archive=Path('/inputs/mobile-source.tar.gz')
assert hashlib.sha256(archive.read_bytes()).hexdigest()==pin['archive_sha256']
with tarfile.open(archive) as tar:
    prefix=tar.getmembers()[0].name.split('/')[0]+'/packages/omamobile-shell/'
    for member in tar.getmembers():
        if member.isfile() and member.name.startswith(prefix+'plugins/'):
            relative=Path(member.name.removeprefix(prefix))
            assert '..' not in relative.parts
            dest=target/'usr/share/omamobile/shell'/relative
            dest.parent.mkdir(parents=True,exist_ok=True)
            dest.write_bytes(tar.extractfile(member).read())
            dest.chmod(0o644)
    for member in tar.getmembers():
        if member.isfile() and member.name.startswith(prefix+'bin/'):
            name=Path(member.name).name
            dest=target/'usr/bin'/name
            dest.write_bytes(tar.extractfile(member).read())
            dest.chmod(0o755)
    license=target/'usr/share/licenses/omamobile-shell/LICENSE'
    license.parent.mkdir(parents=True,exist_ok=True)
    license.write_bytes(tar.extractfile(prefix+'LICENSE').read())
source=Path('/inputs/omarchy-LICENSE')
assert hashlib.sha256(source.read_bytes()).hexdigest()=='717ba1949502290f8e47688ae2e323acd06c8ca47aec9f7596b15f678c1af4a2'
dest=target/'usr/share/licenses/omarchy/LICENSE'
dest.parent.mkdir(parents=True,exist_ok=True)
shutil.copy2(source,dest)

# Preserve the signed host byte-for-byte under a new name; make the minimal
# parent-side forkfd bootstrap the default entry so IPC config paths stay stable.
shell=target/'usr/share/omarchy/shell'
(shell/'shell.qml').replace(shell/'p613-upstream-shell.qml')
shutil.copy2(project/'configs/p613-shell-bootstrap.qml',shell/'shell.qml')

subprocess.run(['patch','--batch','--fuzz=0','-p1','-d',str(target),'-i',str(project/'patches/omamobile/0001-p613-direct-desktop-launch.patch')],check=True)

subprocess.run(['patch','--batch','--fuzz=0','-p1','-d',str(target),'-i',str(project/'patches/omamobile/0002-p613-static-recents-cards.patch')],check=True)
subprocess.run(['patch','--batch','--fuzz=0','-p1','-d',str(target),'-i',str(project/'patches/omamobile/0003-p613-managed-wifi-interface.patch')],check=True)

# The allocation ownership fix is a separately preserved and validated build.
source=Path('/mesa-fixed/libvulkan_freedreno.so')
metadata=json.loads((project/'docs/build-records/mesa-fd-fix-build.json').read_text())
assert hashlib.sha256(source.read_bytes()).hexdigest()==metadata['library_sha256']
shutil.copy2(source,target/'opt/p613-gpu/lib/libvulkan_freedreno.so')
