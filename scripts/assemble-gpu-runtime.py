#!/usr/bin/env python3
"""Run inside graphics container with /mesa, /probes and writable /runtime mounts."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

root = Path('/runtime')
lib = root / 'lib'
binpath = root / 'bin'
lib.mkdir(parents=True, exist_ok=True)
binpath.mkdir(exist_ok=True)
inputs = [Path('/probes/gpu-compute'), Path('/mesa/stage/opt/p613-gpu/lib/libvulkan_freedreno.so')]
for executable in inputs:
    target = (binpath if executable.name == 'gpu-compute' else lib) / executable.name
    shutil.copy2(executable, target)
    output = subprocess.check_output(['ldd', str(executable)], text=True)
    if 'not found' in output:
        raise RuntimeError(output)
    # ldd lists the complete dependency closure, including the interpreter.
    for path in re.findall(r'(?:=>\s+|^\s*)(/[^\s]+)', output, flags=re.MULTILINE):
        dep = Path(path)
        shutil.copy2(dep, lib / dep.name, follow_symlinks=True)
(root / 'turnip.json').write_text(json.dumps({
    'file_format_version': '1.0.0',
    'ICD': {'library_path': '/gpu/lib/libvulkan_freedreno.so', 'api_version': '1.4.0'}
}, indent=2)+'\n')
records=[]
for path in sorted(root.rglob('*')):
    if path.is_file() and path.name != 'manifest.json':
        records.append({'path':str(path.relative_to(root)), 'bytes':path.stat().st_size,
                        'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
(root / 'manifest.json').write_text(json.dumps(records,indent=2)+'\n')
print(json.dumps(records,indent=2))
