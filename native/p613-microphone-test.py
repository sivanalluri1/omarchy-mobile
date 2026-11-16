#!/usr/bin/env python3
"""Ten-second capture signal test; raw audio never leaves RAM and is deleted."""
import array
import json
import math
import os
from pathlib import Path
import re
import subprocess
import wave

assert os.geteuid() == 0
assert os.uname().release == '4.14.357-openela-perf-g21b136df1533'
assert Path('/etc/p613-bringup').is_file()
assert Path('/proc/asound/card0/id').read_text().strip() == 'atollidpsndcard'
os.umask(0o077)
amixer = '/usr/bin/amixer' if Path('/usr/bin/amixer').exists() else '/tmp/amixer'
arecord = '/usr/bin/arecord' if Path('/usr/bin/arecord').exists() else '/tmp/arecord'
route = [
    ('TX_CDC_DMA_TX_3 Channels', 'One'),
    ('TX DEC0 MUX', 'SWR_MIC'),
    ('TX SMIC MUX0', 'ADC0'),
    ('TX_AIF1_CAP Mixer DEC0', 'on'),
    ('ADC1_MIXER Switch', 'on'),
    ('ADC1 Volume', '10'),
    ('MultiMedia1 Mixer TX_CDC_DMA_TX_3', 'on,on'),
]
original = []
result = {'duration_seconds': 10, 'raw_audio_uploaded': False}
path = Path('/tmp/p613-microphone.wav')
try:
    for name, value in route:
        control = "name='"+name+"'"
        text = subprocess.check_output([amixer, '-D', 'hw:0', 'cget', control], text=True)
        values = re.search(r'^\s*: values=(.*)$', text, re.M)
        if not values:
            raise RuntimeError('Unable to snapshot '+name)
        original.append((control, values[1]))
        subprocess.run([amixer, '-q', '-D', 'hw:0', 'cset', control, value], check=True)
    print('P613_MICROPHONE_CAPTURE_START', flush=True)
    subprocess.run([arecord, '-q', '-D', 'hw:0,0', '-f', 'S16_LE', '-r', '16000',
                    '-c', '1', '-d', '10', str(path)], check=True, timeout=20)
    with wave.open(str(path), 'rb') as wav:
        assert wav.getsampwidth() == 2 and wav.getnchannels() == 1
        samples = array.array('h', wav.readframes(wav.getnframes()))
        rate = wav.getframerate()
    result.update({'sample_rate': rate, 'samples': len(samples),
                   'peak': max(map(abs, samples), default=0),
                   'rms': round(math.sqrt(sum(x*x for x in samples)/max(1, len(samples))), 2),
                   'per_second_rms': [round(math.sqrt(sum(x*x for x in samples[i:i+rate])/len(samples[i:i+rate])), 2)
                                      for i in range(0, len(samples), rate)]})
finally:
    path.unlink(missing_ok=True)
    errors = []
    for control, value in reversed(original):
        if subprocess.run([amixer, '-q', '-D', 'hw:0', 'cset', control, value]).returncode:
            errors.append(control)
    result['restored_controls'] = len(original)-len(errors)
    result['restore_failures'] = errors
    result['raw_audio_deleted'] = not path.exists()
    Path('/tmp/p613-microphone-result.json').write_text(json.dumps(result, indent=2)+'\n')
print('P613_MICROPHONE_CAPTURE_FINISHED', flush=True)
