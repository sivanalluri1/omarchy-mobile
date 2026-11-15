#!/usr/bin/env python3
"""Create and structurally inspect a BOOT-only candidate. Never invokes ADB/flashing."""
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys

variant = sys.argv[1] if len(sys.argv) > 1 else 'minimal'
if variant not in ('minimal', 'userspace', 'ram-userspace') or len(sys.argv) > 2:
    raise SystemExit('Usage: package-boot-experiment.py [minimal|userspace|ram-userspace]')
root = Path(__file__).resolve().parent.parent
subprocess.run([sys.executable, str(root / 'scripts/fetch-aosp-tools.py')], check=True)
linux = Path(os.environ.get('OMARCHY_LINUX_ROOT', '/Volumes/OmarchyBuild'))
if not (linux / '.omarchy-storage').is_file():
    raise SystemExit('Mount the configured SSD build image')
template_path = root / 'work/device-backups/boot.img'
template = template_path.read_bytes()
inventory = json.loads((root / 'docs/build-records/installed-image-inventory.json').read_text())
expected = next(x['sha256'] for x in inventory['images'] if x['partition'] == 'boot')
if hashlib.sha256(template).hexdigest() != expected:
    raise SystemExit('Installed boot template hash mismatch')
if template[:8] != b'ANDROID!' or struct.unpack_from('<I', template, 40)[0] != 2:
    raise SystemExit('Expected verified v2 template')
page = struct.unpack_from('<I', template, 36)[0]
align = lambda n: (n + page - 1) // page * page
ks, rs, second = (struct.unpack_from('<I', template, off)[0] for off in (8, 16, 24))
recovery_dtbo = struct.unpack_from('<I', template, 1632)[0]
if second or recovery_dtbo:
    raise SystemExit('Unexpected boot-template second stage or recovery overlay')
dtb_size = struct.unpack_from('<I', template, 1648)[0]
dtb_offset = page + align(ks) + align(rs)
dtb = template[dtb_offset:dtb_offset + dtb_size]
if dtb[:4] != b'\xd0\x0d\xfe\xed':
    raise SystemExit('Invalid template DTB')
output = linux / ('build/boot-experiment' if variant == 'minimal' else f'build/boot-{variant}')
output.mkdir(parents=True, exist_ok=True)
output.chmod(0o700)
(output / 'installed.dtb').write_bytes(dtb)
image = linux / f'build/kernel-{variant}/arch/arm64/boot/Image'
ramdisk = linux / 'build/initramfs/initramfs.cpio.gz'
# Require recorded, inspected inputs; do not accidentally package an old kernel.
for filename, recordfile, field in ((image, f'kernel-{variant}-artifacts.json', None),
                                     (ramdisk, 'initramfs-validation.json', 'archive_sha256')):
    record = json.loads((root / 'docs/build-records' / recordfile).read_text())
    digest = record[field] if field else record['artifacts'][0]['sha256']
    if hashlib.sha256(filename.read_bytes()).hexdigest() != digest:
        raise SystemExit(f'Input changed since validation: {filename}')
os_raw = struct.unpack_from('<I', template, 44)[0]
os_version = '.'.join(str((os_raw >> shift) & 127) for shift in (25, 18, 11))
patch = f'{2000 + ((os_raw >> 4) & 127):04d}-{os_raw & 15:02d}'
cmdline = (template[64:576].split(b'\0', 1)[0] + template[608:1632].split(b'\0', 1)[0]).decode()
if 'skip_initramfs' in cmdline:
    raise SystemExit('Template skips initramfs')
boot = output / 'boot.img'
args = [sys.executable, str(root / 'work/tools/aosp/mkbootimg.py'),
        '--header_version', '2', '--pagesize', str(page), '--base', '0',
        '--kernel', str(image), '--ramdisk', str(ramdisk), '--dtb', str(output / 'installed.dtb'),
        '--kernel_offset', str(struct.unpack_from('<I', template, 12)[0]),
        '--ramdisk_offset', str(struct.unpack_from('<I', template, 20)[0]),
        '--tags_offset', str(struct.unpack_from('<I', template, 32)[0]),
        '--dtb_offset', str(struct.unpack_from('<Q', template, 1652)[0]),
        '--board', template[48:64].split(b'\0', 1)[0].decode(),
        '--os_version', os_version, '--os_patch_level', patch,
        '--cmdline', cmdline, '--output', str(boot)]
subprocess.run(args, check=True)
avb = root / 'work/tools/aosp/avbtool16.py'
subprocess.run([sys.executable, str(avb), 'add_hash_footer', '--image', str(boot),
                '--partition_name', 'boot', '--partition_size', str(len(template)),
                '--algorithm', 'NONE', '--flags', '3', '--rollback_index', '0',
                '--salt', '00' * 32], check=True)
boot.chmod(0o600)
data = boot.read_bytes()
if len(data) != len(template) or data[-64:-60] != b'AVBf':
    raise SystemExit('Invalid partition size or AVB footer')
for off, size in ((12, 4), (20, 4), (32, 4), (36, 12), (48, 528), (608, 1024), (1652, 8)):
    if data[off:off + size] != template[off:off + size]:
        raise SystemExit(f'Unexpected template header change at offset {off}')
new_ks, new_rs = struct.unpack_from('<I', data, 8)[0], struct.unpack_from('<I', data, 16)[0]
new_ramdisk = page + align(new_ks)
new_dtb = new_ramdisk + align(new_rs)
if data[page:page + new_ks] != image.read_bytes():
    raise SystemExit('Packed kernel differs from validated input')
if data[new_ramdisk:new_ramdisk + new_rs] != ramdisk.read_bytes():
    raise SystemExit('Packed ramdisk differs from validated input')
if data[new_dtb:new_dtb + dtb_size] != dtb:
    raise SystemExit('Packed device tree differs from installed DTB')
v_offset, v_size = struct.unpack_from('>QQ', data, len(data) - 44)
v = data[v_offset:v_offset + v_size]
if v[:4] != b'AVB0' or struct.unpack_from('>I', v, 28)[0] != 0 or struct.unpack_from('>I', v, 120)[0] != 3:
    raise SystemExit('Unexpected AVB metadata')
subprocess.run([sys.executable, str(avb), 'verify_image', '--image', str(boot)], check=True)
report = {'candidate_bytes': len(data), 'candidate_sha256': hashlib.sha256(data).hexdigest(),
          'header_version': 2, 'page_size': page, 'template_header_addresses_os_fields_cmdline_preserved': True,
          'installed_dtb_preserved': True, 'avb_algorithm': 'NONE', 'avb_flags': 3,
          'planned_partition_change': ['BOOT'], 'flashed': False, 'hardware_boot_tested': False}
(root / 'docs/build-records' / ('boot-experiment-validation.json' if variant == 'minimal' else f'boot-{variant}-validation.json')).write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
