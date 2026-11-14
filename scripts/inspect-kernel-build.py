#!/usr/bin/env python3
"""Run inside builder with /out and /checkout mounted read-only; emit JSON."""
import hashlib
import json
from pathlib import Path
import struct
import subprocess

out = Path('/out')
source = Path('/checkout/kernel')

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()

def artifact(path):
    return {'path': str(path.relative_to(out)), 'bytes': path.stat().st_size,
            'sha256': digest(path)}

image = out / 'arch/arm64/boot/Image'
vmlinux = out / 'vmlinux'
with image.open('rb') as stream:
    header = stream.read(64)
if len(header) != 64 or header[56:60] != b'ARM\x64':
    raise SystemExit('Invalid AArch64 Linux Image header')
with vmlinux.open('rb') as stream:
    elf = stream.read(20)
if elf[:6] != b'\x7fELF\x02\x01' or struct.unpack_from('<H', elf, 18)[0] != 183:
    raise SystemExit('vmlinux is not little-endian ELF64 AArch64')
blobs = sorted((out / 'arch/arm64/boot/dts').rglob('*.dtb'))
blobs += sorted((out / 'arch/arm64/boot/dts').rglob('*.dtbo'))
if not blobs:
    raise SystemExit('No device trees generated')
for blob in blobs:
    with blob.open('rb') as stream:
        magic, size = struct.unpack('>II', stream.read(8))
    if magic != 0xd00dfeed or size > blob.stat().st_size:
        raise SystemExit(f'Invalid device-tree header: {blob}')
if not any('gta4xlve' in b.name for b in blobs):
    raise SystemExit('Missing tablet device-tree blob')
revision = subprocess.check_output(['git', '-c', f'safe.directory={source}', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
dirty = subprocess.check_output(['git', '-c', f'safe.directory={source}', '-C', str(source), 'status', '--porcelain'], text=True)
if dirty:
    raise SystemExit('Source modified during build')
report = {'source_revision': revision, 'source_clean': True,
          'compiler': subprocess.check_output(['clang', '--version'], text=True).splitlines()[0],
          'config_sha256': digest(out / '.config'),
          'image_header_valid': True, 'vmlinux_architecture': 'AArch64 ELF64 little-endian',
          'artifacts': [artifact(image), artifact(vmlinux)],
          'device_tree_blob_count': len(blobs),
          'tablet_device_trees': [artifact(b) for b in blobs if 'gta4xlve' in b.name],
          'hardware_tested': False, 'flashable_boot_image_created': False}
print(json.dumps(report, indent=2))
