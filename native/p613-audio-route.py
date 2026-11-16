#!/usr/bin/env python3
"""Enable/restore the speaker and main-microphone routes proven by ALSA tests."""
import argparse
import grp
import json
import os
from pathlib import Path
import re
import stat
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('action', choices=['enable', 'restore'])
a = p.parse_args()
assert os.geteuid() == 0
assert os.uname().release == '4.14.357-openela-perf-g21b136df1533'
assert Path('/etc/p613-bringup').is_file()
assert Path('/proc/asound/card0/id').read_text().strip() == 'atollidpsndcard'
state = Path('/run/p613-audio-route.json')
route = [('QUIN_MI2S_RX Channels', 'Two'), ('QUIN_MI2S_RX Format', 'S16_LE'),
         ('QUIN_MI2S_RX SampleRate', 'KHZ_48'), ('TAS256X ASI1 SEL LEFT', 'Left'),
         ('TAS256X ASI1 SEL RIGHT', 'Right'), ('QUIN_MI2S_RX Audio Mixer MultiMedia1', 'on,on'),
         ('TAS256X ASI Left Switch', 'on'), ('TAS256X ASI Right Switch', 'on')]
route += [('TX_CDC_DMA_TX_3 Channels', 'One'), ('TX DEC0 MUX', 'SWR_MIC'),
          ('TX SMIC MUX0', 'ADC0'), ('TX_AIF1_CAP Mixer DEC0', 'on'),
          ('ADC1_MIXER Switch', 'on'), ('ADC1 Volume', '10'),
          ('MultiMedia1 Mixer TX_CDC_DMA_TX_3', 'on,on')]
if a.action == 'enable':
    assert not state.exists(), 'Audio route already enabled'
    group = grp.getgrnam('audio').gr_gid
    for node in Path('/dev/snd').iterdir():
        info = node.stat()
        if stat.S_ISCHR(info.st_mode) and os.major(info.st_rdev) == 116:
            os.chown(node, 0, group)
            node.chmod(0o660)
    original = []
    try:
        for name, value in route:
            control = "name='"+name+"'"
            output = subprocess.check_output(['amixer', '-D', 'hw:0', 'cget', control], text=True)
            match = re.search(r'^\s*: values=(.*)$', output, re.M)
            assert match, name
            original.append((control, match[1]))
            subprocess.run(['amixer', '-q', '-D', 'hw:0', 'cset', control, value], check=True)
    except Exception:
        for control, value in reversed(original):
            subprocess.run(['amixer', '-q', '-D', 'hw:0', 'cset', control, value])
        raise
    state.write_text(json.dumps(original)+'\n')
    state.chmod(0o600)
    print('P613_AUDIO_ROUTES_ENABLED')
elif state.exists():
    allowed = {"name='"+name+"'" for name, _ in route}
    for control, value in reversed(json.loads(state.read_text())):
        assert control in allowed
        subprocess.run(['amixer', '-q', '-D', 'hw:0', 'cset', control, value], check=True)
    state.unlink()
    print('P613_AUDIO_ROUTES_RESTORED')
