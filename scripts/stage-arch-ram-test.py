#!/usr/bin/env python3
"""Stage a verified RAM-only Arch experiment over pinned-key SSH. Never flashes/reboots."""
import argparse
import datetime
import hashlib
import io
import json
from pathlib import Path
import shlex
import subprocess
import tarfile

root=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser()
parser.add_argument('--compat-udev',action='store_true',help='Stage the previously tested libudev 257 in a private RAM prefix')
args=parser.parse_args()
# The local SSD paths are private configuration, not a guessed system directory.
lines=(root/'storage.local.env').read_text().splitlines()
settings=dict(line.split('=',1) for line in lines if line and not line.startswith('#'))
base=Path(settings['OMARCHY_LINUX_ROOT'])
assert (base/'.omarchy-storage').is_file()
state=subprocess.check_output(['ifconfig','en5'],text=True)
assert 'inet 192.168.77.2 ' in state and '02:61:30:00:00:02' in state
log=root/'work/hardware-test-06/reconnected'
log.mkdir(parents=True,exist_ok=True)
ssh=['ssh','-T','-i',str(root/'work/keys/client_ed25519'),'-o','UserKnownHostsFile='+str(root/'work/keys/tablet_known_hosts'),'-o','StrictHostKeyChecking=yes','-o','BatchMode=yes','-o','ConnectTimeout=10','-o','ServerAliveInterval=3','-o','ServerAliveCountMax=2','root@192.168.77.1']
def run(command,name,timeout=60):
    p=subprocess.run(ssh+[command],capture_output=True,timeout=timeout)
    (log/name).write_bytes(p.stdout+p.stderr)
    p.check_returncode()
    return p.stdout

def put(source,dest,mode='700'):
    with source.open('rb') as stream:
        subprocess.run(ssh+['cat >'+shlex.quote(dest)+'; chmod '+mode+' '+shlex.quote(dest)],stdin=stream,check=True,timeout=180)
    expected=hashlib.sha256(source.read_bytes()).hexdigest()
    actual=run('sha256sum '+shlex.quote(dest),source.name+'.sha256').decode().split()[0]
    assert actual==expected,dest

record=json.loads((root/'docs/build-records/boot-ram-userspace-validation.json').read_text())
readback=run('sha256sum /dev/sda19; test ! -b /dev/nbd0; test ! -e /run/arch-root-mounted','preflight.txt').decode().split()[0]
assert readback==record['candidate_sha256']
stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d %H:%M:%S')
run('date -u -s '+shlex.quote(stamp),'clock.txt')
manifest=json.loads((root/'docs/build-records/graphics-firmware.json').read_text())
archive=io.BytesIO()
with tarfile.open(fileobj=archive,mode='w:gz') as tar:
    for item in manifest:
        source=root/'work/hardware-test-02/firmware'/item['name']
        assert hashlib.sha256(source.read_bytes()).hexdigest()==item['sha256']
        for prefix in ['lib/firmware/','vendor/firmware_mnt/image/']:
            tar.add(source,arcname=prefix+source.name,recursive=False)
subprocess.run(ssh+['cd /; tar -xzf -'],input=archive.getvalue(),check=True,timeout=30)
for name in ['graphics-probe','display-test']:
    put(base/'build/graphics-probes'/name,'/tmp/'+name)
run('/tmp/graphics-probe','native-gpu-enumeration.txt')
print('Native BOOT, no-NBD kernel and GPU enumeration verified',flush=True)
image=base/'build/arch-ram/arch-root.squashfs'
expected=json.loads((root/'docs/build-records/arch-ram-root-build.json').read_text())['sha256']
assert hashlib.sha256(image.read_bytes()).hexdigest()==expected
print('Transferring compressed Arch image into RAM',flush=True)
put(image,'/arch-root.squashfs','600')
for name in ['mount-arch-ram-root.sh','unmount-arch-ram-root.sh','run-arch-hyprland-test.sh']:
    put(root/'native'/name,'/tmp/'+name)
run('/tmp/mount-arch-ram-root.sh '+expected,'arch-mount.txt')
for source,dest,mode in [(root/'native/arch-hyprland-worker.sh','/arch/tmp/arch-hyprland-worker.sh','755'),(base/'build/gpu-probes/gpu-render','/arch/tmp/gpu-render','755'),(base/'build/gpu-probes/udev-probe','/arch/tmp/udev-probe','755'),(root/'configs/hyprland-p613-debug.lua','/arch/tmp/hyprland-debug.lua','644')]:
    put(source,dest,mode)
if args.compat_udev:
    runtime=base/'build/wayland-runtime-final'
    metadata=json.loads((root/'docs/build-records/wayland-build.json').read_text())
    assert hashlib.sha256((runtime/'manifest.json').read_bytes()).hexdigest()==metadata['runtime_manifest_sha256']
    old=next(m for m in json.loads((runtime/'manifest.json').read_text()) if m['path']=='gpu/lib/libudev.so.1')
    source=runtime/old['path']
    assert hashlib.sha256(source.read_bytes()).hexdigest()==old['sha256']
    run('mkdir -p /arch/tmp/p613-compat; chmod 755 /arch/tmp/p613-compat','compat-directory.txt')
    put(source,'/arch/tmp/p613-compat/libudev.so.1','644')
run('cat /proc/mounts; grep MemAvailable /proc/meminfo','mounts-memory.txt')
print('Arch RAM root and test tools staged; no compositor started',flush=True)
