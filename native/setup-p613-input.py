#!/usr/bin/env python3
"""Classify tablet and USB keyboard/mouse devices in the RAM-only udev DB.

The minimal init has no udev daemon. No firmware or persistent calibration is changed; classification uses kernel device names, not event IDs.
"""
import grp
import fcntl
import os
from pathlib import Path
import stat
import struct
import time

assert os.geteuid()==0
assert Path('/etc/p613-bringup').is_file()
assert os.uname().release.startswith('4.14.357-openela-perf-g21b136df1533')
classes={'sec_touchscreen':'ID_INPUT_TOUCHSCREEN','sec_e-pen':'ID_INPUT_TABLET',
         'qpnp_pon':'ID_INPUT_KEY','gpio-keys':'ID_INPUT_KEY'}
directory=Path('/run/udev/data')
directory.mkdir(parents=True,exist_ok=True)
found=set()
def usb_classes(node):
    """Use evdev bus/capabilities, without reading any input events."""
    fd=os.open(node,os.O_RDONLY|os.O_NONBLOCK)
    try:
        bus,_,_,_=struct.unpack('4H',fcntl.ioctl(fd,0x80084502,bytes(8)))
        if bus != 3:  # BUS_USB; never reinterpret unknown internal sensors.
            return []
        def bits(kind,length):
            return int.from_bytes(fcntl.ioctl(fd,0x80000000|(length<<16)|(ord('E')<<8)|(0x20+kind),bytes(length)),'little')
        keys=bits(1,96)
        relative=bits(2,8)
        result=[]
        if all(keys & (1<<key) for key in (30,44,28,57)):
            result += ['ID_INPUT_KEYBOARD','ID_INPUT_KEY']
        if keys & (1<<272) and relative & 3 == 3:
            result += ['ID_INPUT_MOUSE']
        return result
    finally:
        os.close(fd)

for event in Path('/sys/class/input').glob('event*'):
    name=(event/'device/name').read_text().strip()
    node=Path('/dev/input')/event.name
    info=node.stat()
    assert stat.S_ISCHR(info.st_mode) and os.major(info.st_rdev)==13
    device_classes=[classes[name]] if name in classes else usb_classes(node)
    if not device_classes:
        continue
    os.chown(node,0,grp.getgrnam('input').gr_gid)
    node.chmod(0o660)
    if name=='sec_e-pen':
        # Panel source specifies 135.3 x 225.6 mm; firmware axes are
        # 13536 x 22560 units. Only supply the missing 100 units/mm.
        # EVIOCSABS is volatile; preserve range, fuzz, flat and current value.
        fd=os.open(node,os.O_RDWR|os.O_NONBLOCK)
        try:
            for axis,maximum in [(0,13536),(1,22560)]:
                values=list(struct.unpack('6i',fcntl.ioctl(fd,0x80184540+axis,bytes(24))))
                assert values[1:3]==[0,maximum] and values[5] in [0,100]
                values[5]=100
                fcntl.ioctl(fd,0x401845c0+axis,struct.pack('6i',*values))
                actual=struct.unpack('6i',fcntl.ioctl(fd,0x80184540+axis,bytes(24)))
                assert actual[5]==100
            print('INPUT_PEN_RESOLUTION units_per_mm=100 ranges_preserved=true')
        finally:
            os.close(fd)
    major,minor=os.major(info.st_rdev),os.minor(info.st_rdev)
    properties=['ID_INPUT=1']+[value+'=1' for value in device_classes]+['ID_SEAT=seat0','WL_SEAT=seat0']
    if name not in classes:
        properties += ['ID_BUS=usb']
    lines=['I:'+str(int(time.monotonic()*1000000)),'V:1']
    lines += ['E:'+p for p in properties]
    lines += ['G:seat','Q:seat']
    dest=directory/f'c{major}:{minor}'
    dest.write_text('\n'.join(lines)+'\n')
    dest.chmod(0o644)
    print(f'INPUT_CLASSIFIED name={name} node={event.name} properties={device_classes}')
    found.add(name)
assert {'sec_touchscreen','sec_e-pen'} <= found
