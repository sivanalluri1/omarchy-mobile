#!/usr/bin/env python3
"""Play quiet synthetic stereo tones through the normal PipeWire speaker sink."""
import argparse
import json
import math
import os
from pathlib import Path
import struct
import subprocess
import wave

assert os.getuid() == 1000
assert Path('/etc/p613-bringup').is_file()
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--backend', choices=['pipewire', 'pulse'], default='pipewire')
p.add_argument('--seconds', type=int, default=30)
a = p.parse_args()
assert 5 <= a.seconds <= 30
path = Path('/tmp/p613-pipewire-tone.wav')
result = {'seconds': a.seconds, 'sample_rate': 48000, 'channels': 2,
          'synthetic_peak_pcm_value': 1536, 'target': 'p613-speakers', 'backend': a.backend}
with wave.open(str(path), 'wb') as wav:
    wav.setparams((2, 2, 48000, 0, 'NONE', 'not compressed'))
    chunk = bytearray()
    for i in range(a.seconds*48000):
        t = i/48000
        phase = t % 5
        left = int(1536*math.sin(2*math.pi*440*t)) if phase < 2 else 0
        right = int(1536*math.sin(2*math.pi*660*t)) if 2 <= phase < 4 else 0
        chunk.extend(struct.pack('<hh', left, right))
        if len(chunk) >= 65536:
            wav.writeframesraw(chunk)
            chunk.clear()
    wav.writeframesraw(chunk)
try:
    print('P613_PIPEWIRE_PLAYBACK_START', flush=True)
    command = ['pw-play', '--target', 'p613-speakers'] if a.backend == 'pipewire' else ['paplay', '--device=p613-speakers']
    r = subprocess.run(command+[str(path)], timeout=a.seconds+15)
    result['pw_play_exit'] = r.returncode
    r.check_returncode()
finally:
    path.unlink(missing_ok=True)
    result['synthetic_file_deleted'] = not path.exists()
    Path('/tmp/p613-'+a.backend+'-result.json').write_text(json.dumps(result, indent=2)+'\n')
print('P613_PIPEWIRE_PLAYBACK_FINISHED', flush=True)
