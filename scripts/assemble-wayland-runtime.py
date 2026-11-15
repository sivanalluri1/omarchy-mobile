#!/usr/bin/env python3
"""Run inside graphics container: /mesa, /probes, /project readonly; /runtime writable.
The output is a RAM-root overlay; no Android filesystems are involved.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

root=Path('/runtime')
gpu=root/'gpu'
lib=gpu/'lib'
binpath=gpu/'bin'
binpath.mkdir(parents=True,exist_ok=True)
custom=Path('/mesa/stage/opt/p613-gpu/lib')
shutil.copytree(custom,lib,symlinks=True,dirs_exist_ok=True)
westonroot=Path('/weston/stage') if os.environ.get('USE_PATCHED_WESTON')=='1' else Path('/')
westonlibs=westonroot/'usr/lib/aarch64-linux-gnu'
env=dict(os.environ,LD_LIBRARY_PATH=':'.join([str(custom),str(westonlibs),str(westonlibs/'weston')]))
inputs=[Path('/probes/gpu-compute'),Path('/probes/gpu-render'),Path('/probes/gbm-probe'),
        Path('/graphics-probes/display-test'),
        westonroot/'usr/bin/weston',westonroot/'usr/bin/weston-simple-egl']
plugins=[westonlibs/'libweston-14'/name for name in
         ['drm-backend.so','gl-renderer.so','color-lcms.so']]
plugins=[p for p in plugins if p.exists()]
plugins.append(westonlibs/'weston/kiosk-shell.so')
for executable in inputs:
    shutil.copy2(executable,binpath/executable.name)
for plugin in plugins:
    dest=root/plugin.relative_to(westonroot)
    dest.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(plugin,dest)
# Include dependencies of every custom ELF and plugin, not just direct binary deps.
elfs=inputs+plugins+[p for p in custom.rglob('*') if p.is_file() and not p.is_symlink()
                    and p.read_bytes()[:4]==b'\x7fELF']
for executable in elfs:
    if executable.name=='display-test':
        continue  # Independently validated static ARM64 executable.
    output=subprocess.check_output(['ldd',str(executable)],text=True,env=env)
    if 'not found' in output:
        raise RuntimeError(output)
    for path in re.findall(r'(?:=>\s+|^\s*)(/[^\s]+)',output,flags=re.MULTILINE):
        dep=Path(path)
        dest=lib/dep.name
        if dest.exists():
            if dest.read_bytes()!=dep.read_bytes():
                raise RuntimeError(f'Conflicting runtime dependency: {dep}')
        else:
            shutil.copy2(dep,dest,follow_symlinks=True)
shutil.copy2('/project/native/run-wayland-test.sh',binpath/'run-wayland-test.sh')
shutil.copy2('/project/configs/weston-test.ini',gpu/'weston-test.ini')
(gpu/'turnip.json').write_text(json.dumps({'file_format_version':'1.0.0',
    'ICD':{'library_path':'/gpu/lib/libvulkan_freedreno.so','api_version':'1.4.0'}},indent=2)+'\n')
shutil.copytree('/usr/share/X11/xkb',root/'usr/share/X11/xkb',symlinks=True,dirs_exist_ok=True)
# Supply libinput quirks where the distro library expects them. Input remains a later gate.
if Path('/usr/share/libinput').exists():
    shutil.copytree('/usr/share/libinput',root/'usr/share/libinput',dirs_exist_ok=True)
records=[]
for path in sorted(root.rglob('*')):
    if path.is_file() and path.name!='manifest.json':
        records.append({'path':str(path.relative_to(root)),'bytes':path.stat().st_size,
                        'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                        'symlink':os.readlink(path) if path.is_symlink() else None})
(root/'manifest.json').write_text(json.dumps(records,indent=2)+'\n')
print(f'Runtime ready: {len(records)} files')
