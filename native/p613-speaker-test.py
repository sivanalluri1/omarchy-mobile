#!/usr/bin/env python3
"""Bounded low-level stereo playback using the tablet vendor's speaker route.

Only routing/format controls are changed. Amp gain, limiter, boost and
calibration controls are untouched. Original values are restored afterward.
"""
import argparse
import json
import math
import os
from pathlib import Path
import re
import struct
import subprocess
import wave

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--seconds', type=int, default=30)
a = p.parse_args()
assert 5 <= a.seconds <= 30
assert os.geteuid() == 0
assert os.uname().release == '4.14.357-openela-perf-g21b136df1533'
assert Path('/etc/p613-bringup').is_file()
assert Path('/proc/asound/card0/id').read_text().strip() == 'atollidpsndcard'
amixer = '/usr/bin/amixer' if Path('/usr/bin/amixer').exists() else '/tmp/amixer'
aplay = '/usr/bin/aplay' if Path('/usr/bin/aplay').exists() else '/tmp/aplay'
route = [
    ('QUIN_MI2S_RX Channels', 'Two'),
    ('QUIN_MI2S_RX Format', 'S16_LE'),
    ('QUIN_MI2S_RX SampleRate', 'KHZ_48'),
    ('TAS256X ASI1 SEL LEFT', 'Left'),
    ('TAS256X ASI1 SEL RIGHT', 'Right'),
    ('QUIN_MI2S_RX Audio Mixer MultiMedia1', 'on,on'),
    ('TAS256X ASI Left Switch', 'on'),
    ('TAS256X ASI Right Switch', 'on'),
]
original = []
result = {'sample_rate': 48000, 'channels': 2, 'sample_format': 'S16_LE',
          'peak_pcm_value': 512, 'seconds': a.seconds, 'analog_gain_changed': False}
tone = Path('/tmp/p613-stereo-tone.wav')
with wave.open(str(tone), 'wb') as wav:
    wav.setparams((2, 2, 48000, 0, 'NONE', 'not compressed'))
    chunk = bytearray()
    for frame in range(a.seconds*48000):
        t = frame/48000
        phase = t % 5
        left = int(512*math.sin(2*math.pi*440*t)) if phase < 2 else 0
        right = int(512*math.sin(2*math.pi*660*t)) if 2 <= phase < 4 else 0
        chunk.extend(struct.pack('<hh', left, right))
        if len(chunk) >= 65536:
            wav.writeframesraw(chunk)
            chunk.clear()
    wav.writeframesraw(chunk)
try:
    for name, value in route:
        control = "name='"+name+"'"
        before = subprocess.check_output([amixer, '-D', 'hw:0', 'cget', control], text=True)
        match = re.search(r'^\s*: values=(.*)$', before, re.M)
        if not match:
            raise RuntimeError('Unable to snapshot '+name)
        original.append((control, match[1]))
        subprocess.run([amixer, '-q', '-D', 'hw:0', 'cset', control, value], check=True)
    print('P613_STEREO_PLAYBACK_START', flush=True)
    play = subprocess.run([aplay, '-D', 'hw:0,0', str(tone)], timeout=a.seconds+15)
    result['aplay_exit'] = play.returncode
    play.check_returncode()
finally:
    errors = []
    for control, value in reversed(original):
        r = subprocess.run([amixer, '-q', '-D', 'hw:0', 'cset', control, value])
        if r.returncode:
            errors.append(control)
    result['restored_controls'] = len(original)-len(errors)
    result['restore_failures'] = errors
    Path('/tmp/p613-speaker-result.json').write_text(json.dumps(result, indent=2)+'\n')
    tone.unlink(missing_ok=True)
print('P613_STEREO_PLAYBACK_FINISHED', flush=True)
