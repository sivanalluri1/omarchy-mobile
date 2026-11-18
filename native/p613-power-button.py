#!/usr/bin/env python3
"""Native P613 Power-button supervisor; no logind, PIN lock or power-off action.

Short press: display toggle on USB; display-off + optional deep sleep unplugged.
Only qpnp_pon/KEY_POWER is observed. No input grab or other key logging.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import select
import signal
import struct
import subprocess
import time

KERNEL = '4.14.357-openela-perf-g21b136df1533'
EVENT = struct.Struct('@llHHi')
STATE = Path('/run/p613-power-button.json')
PID = Path('/run/p613-power-button.pid')
stop = False

def clock():
    return time.clock_gettime(time.CLOCK_BOOTTIME)

def status(phase, **extra):
    data = {'phase': phase, 'boottime': round(clock(), 3), **extra}
    temp = STATE.with_suffix('.json.new')
    temp.write_text(json.dumps(data)+'\n')
    temp.replace(STATE)
    print(json.dumps(data), flush=True)

def command(args, timeout=10, check=True):
    p = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    if check and p.returncode:
        raise RuntimeError(f'{Path(args[0]).name} exited {p.returncode}')
    return p

def user(*args):
    return command(['runuser', '-u', 'omarchy', '--', 'env',
                    'XDG_RUNTIME_DIR=/run/user/1000', 'WAYLAND_DISPLAY=wayland-1',
                    'OMARCHY_PATH=/usr/share/omarchy', *args])

def dpms():
    monitors = json.loads(user('hyprctl', '-i', '0', '-j', 'monitors').stdout)
    panel = [m for m in monitors if m['name'] == 'DSI-1' and not m['disabled']]
    if len(panel) != 1:
        raise RuntimeError('expected one enabled DSI-1 panel')
    return panel[0]['dpmsStatus']

def display(on):
    action = 'on' if on else 'off'
    user('hyprctl', '-i', '0', 'dispatch', 'hl.dsp.dpms({action="'+action+'"})')

def unplugged():
    # Carrier plus charger status is deliberately conservative during USB reset.
    return (Path('/sys/class/net/usb0/carrier').read_text().strip() == '0'
            and Path('/sys/class/power_supply/battery/status').read_text().strip() == 'Discharging')

def wifi():
    value = command(['nmcli', '-t', '-f', 'WIFI', 'general']).stdout.strip()
    if value not in ('enabled', 'disabled'):
        raise RuntimeError('unknown Wi-Fi radio state')
    return value

def wifi_set(enabled):
    command(['nmcli', 'radio', 'wifi', 'on' if enabled else 'off'])

def interrupted(signum, frame):
    global stop
    stop = True


def settle(fd, seconds):
    deadline = clock()+seconds
    while clock() < deadline:
        if stop or not unplugged():
            status('sleep_cancelled', reason='stop_or_usb_attached')
            return False
        if select.select([fd], [], [], min(0.2, max(0, deadline-clock())))[0]:
            data = os.read(fd, EVENT.size*32)
            for offset in range(0, len(data), EVENT.size):
                _, _, kind, code, value = EVENT.unpack_from(data, offset)
                if kind == 1 and code == 116 and value == 1:
                    status('sleep_cancelled', reason='power_pressed_during_preparation')
                    return False
    return True


def suspend(probe, fallback, fd):
    pm = Path('/sys/power/pm_async')
    old_pm = pm.read_text().strip()
    old_wifi = wifi()
    if old_pm not in ('0', '1'):
        raise RuntimeError('unknown pm_async state')
    try:
        if old_wifi == 'enabled':
            wifi_set(False)
        # Give the tested vendor radio shutdown path time to settle.
        if not settle(fd, 10):
            return
        pm.write_text('0')
        mode = 'button' if fallback else 'sleep'
        for attempt in range(1, 4):
            if stop or not unplugged():
                status('sleep_cancelled', reason='stop_or_usb_attached')
                return
            status('suspending', attempt=attempt, rtc_fallback_seconds=fallback)
            result = command([str(probe), mode], timeout=35, check=False)
            match = re.search(r'suspended_seconds=([0-9.]+)', result.stdout)
            slept = float(match.group(1)) if match else None
            if result.returncode in (3, 4):
                status('sleep_busy', attempt=attempt, exit_code=result.returncode)
                time.sleep(2)
                continue
            if result.returncode:
                raise RuntimeError(f'suspend probe exited {result.returncode}')
            status('resumed', suspended_seconds=slept, rtc_fallback_seconds=fallback)
            return
        raise RuntimeError('bounded suspend attempts exhausted')
    finally:
        # Attempt every restoration independently, including after a sysfs error.
        restore_errors = []
        try:
            if pm.read_text().strip() != old_pm:
                pm.write_text(old_pm)
        except Exception as error:
            restore_errors.append('pm_async: '+str(error))
        try:
            wifi_set(old_wifi == 'enabled')
        except Exception as error:
            restore_errors.append('wifi: '+str(error))
        try:
            display(True)
        except Exception as error:
            restore_errors.append('display: '+str(error))
        if restore_errors:
            raise RuntimeError('restore failed: '+'; '.join(restore_errors))



def main():
    global stop
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--allow-suspend', action='store_true')
    p.add_argument('--rtc-fallback', type=int, choices=[0, 90], default=90)
    p.add_argument('--probe', type=Path, default=Path('/usr/local/libexec/p613/suspend-probe'))
    args = p.parse_args()
    if os.geteuid() != 0 or os.uname().release != KERNEL or not Path('/etc/p613-bringup').is_file():
        raise SystemExit('requires the validated native P613 root session')
    if args.allow_suspend and not (args.probe.is_absolute() and args.probe.is_file()):
        raise SystemExit('missing absolute suspend-probe path')
    lock = open('/run/p613-power-button.lock', 'w')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    devices = [d for d in Path('/sys/class/input').glob('event*')
               if (d/'device/name').read_text().strip() == 'qpnp_pon']
    if len(devices) != 1:
        raise SystemExit('expected one qpnp_pon input device')
    fd = os.open('/dev/input/'+devices[0].name, os.O_RDONLY | os.O_NONBLOCK)
    PID.write_text(str(os.getpid())+'\n')
    down = None
    guard = 0.0
    try:
        # The supervisor can start alongside Hyprland; never consume keys early.
        for attempt in range(30):
            try:
                dpms()
                break
            except (RuntimeError, ValueError):
                if stop: return
                time.sleep(1)
        else:
            raise RuntimeError('compositor not ready')
        # Do not act on key transitions accumulated before startup readiness.
        while select.select([fd], [], [], 0)[0]: os.read(fd, EVENT.size*32)
        status('ready', allow_suspend=args.allow_suspend, rtc_fallback_seconds=args.rtc_fallback)
        while not stop:
            if not select.select([fd], [], [], 0.5)[0]:
                continue
            data = os.read(fd, EVENT.size*32)
            if len(data) % EVENT.size:
                raise RuntimeError('partial input event')
            for offset in range(0, len(data), EVENT.size):
                _, _, kind, code, value = EVENT.unpack_from(data, offset)
                if kind != 1 or code != 116:  # EV_KEY / KEY_POWER only
                    continue
                if clock() < guard:
                    down = None
                    continue
                if value == 1:
                    down = clock()
                elif value == 0 and down is not None:
                    held = clock()-down
                    down = None
                    if held > 1.5:
                        status('long_press_ignored')
                        continue
                    attempted_sleep = False
                    try:
                        if not dpms():
                            display(True)
                            status('display_on')
                        else:
                            display(False)
                            if args.allow_suspend and unplugged():
                                attempted_sleep = True
                                time.sleep(0.6)
                                suspend(args.probe, args.rtc_fallback, fd)
                            else:
                                status('display_off', reason='usb_or_display_only_mode')
                    except Exception as error:
                        status('error', detail=str(error))
                        try: display(True)
                        except Exception: pass
                    finally:
                        # A wake press must not be interpreted as a fresh sleep.
                        down = None
                        guard = clock()+(1.5 if attempted_sleep else 0.15)
                        if attempted_sleep:
                            while select.select([fd], [], [], 0)[0]: os.read(fd, EVENT.size*32)
    finally:
        os.close(fd)
        PID.unlink(missing_ok=True)
        try: display(True)
        except Exception: pass
        status('stopped')

if __name__ == '__main__':
    main()
