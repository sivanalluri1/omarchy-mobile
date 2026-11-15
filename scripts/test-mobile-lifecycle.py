#!/usr/bin/env python3
"""Bounded hardware regression: close Foot windows while recents is visible."""
import argparse
import json
from pathlib import Path
import shlex
import subprocess
import time

parser=argparse.ArgumentParser()
parser.add_argument('--close-test-windows',action='store_true',required=True)
parser.add_argument('--cycles',type=int,choices=range(1,11),default=5)
args=parser.parse_args()
root=Path(__file__).resolve().parent.parent
logs=root/'work/hardware-test-08/lifecycle'
logs.mkdir(parents=True,exist_ok=True)
ssh=['ssh','-T','-i',str(root/'work/keys/client_ed25519'),'-o',
     'UserKnownHostsFile='+str(root/'work/keys/tablet_known_hosts'),'-o','StrictHostKeyChecking=yes',
     '-o','BatchMode=yes','-o','ConnectTimeout=10','-o','ServerAliveInterval=3',
     '-o','ServerAliveCountMax=2','root@192.168.77.1']
def remote(command):
    result=subprocess.run(ssh+[command],capture_output=True,text=True,timeout=30)
    result.check_returncode()
    return result.stdout.strip()

boot=remote('sha256sum /dev/sda19').split()[0]
assert boot==json.loads((root/'docs/build-records/boot-ram-userspace-validation.json').read_text())['candidate_sha256']
assert 'compressed RAM image' in remote('cat /run/arch-root-transport')
prefix='chroot /arch /usr/bin/runuser -u omarchy -- /usr/bin/env XDG_RUNTIME_DIR=/run/user/1000 '
sockets=remote('find /arch/run/user/1000 -maxdepth 1 -type s -name "wayland-*"').splitlines()
assert len(sockets)==1
display=Path(sockets[0]).name
shell=prefix+'WAYLAND_DISPLAY='+shlex.quote(display)+' OMARCHY_PATH=/usr/share/omarchy /usr/bin/omarchy-shell '
hypr=prefix+'/usr/bin/hyprctl -i 0 '
def clients():
    value=json.loads(remote(hypr+'-j clients'))
    assert all(c['class']=='foot' for c in value), 'Refusing to close non-test applications'
    return value
def dispatch(expression):
    assert remote(hypr+'dispatch '+shlex.quote(expression))=='ok'
def ping():
    assert remote(shell+'shell ping')=='ok'

clients()
results=[]
for cycle in range(1,args.cycles+1):
    before={c['address'] for c in clients()}
    dispatch('hl.dsp.exec_cmd([[omamobile-launch app foot]])')
    for attempt in range(20):
        time.sleep(0.25)
        windows=clients()
        if any(c['address'] not in before for c in windows):break
    else:raise RuntimeError('Foot did not map')
    remote(shell+'shell summon omamobile.switcher '+shlex.quote('{}'))
    time.sleep(0.5)
    # Keep recents visible as the actual toplevels disappear: this hit the
    # live-capture protocol race. Only the validated Foot windows are closed.
    for window in windows:
        selector='address:'+window['address']
        dispatch('hl.dsp.window.close({ window = '+json.dumps(selector)+' })')
    for attempt in range(20):
        time.sleep(0.25)
        if not clients():break
    else:raise RuntimeError('Foot windows did not close')
    ping()
    remote(shell+'shell hide omamobile.switcher')
    home=json.loads(remote(shell+"shell call omamobile.home state ''"))
    assert home['loaded'] and home['pages']>0
    result={'cycle':cycle,'foot_mapped':True,'windows_closed_with_recents_visible':len(windows),
            'shell_ping':True,'home_loaded':True}
    results.append(result)
    (logs/'results.json').write_text(json.dumps(results,indent=2)+'\n')
    print('MOBILE_LIFECYCLE_PASS cycle='+str(cycle),flush=True)
print('MOBILE_LIFECYCLE_FINISHED',flush=True)
