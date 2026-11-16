#!/usr/bin/env python3
"""Short desktop speaker/microphone test; retain statistics, delete all audio."""
import array
import json
import math
import os
from pathlib import Path
import signal
import struct
import subprocess
import time
import wave

assert os.getuid() == 1000
assert Path('/etc/p613-bringup').is_file()
os.umask(0o077)
tone = Path('/tmp/p613-loopback-tone.wav')
capture = Path('/tmp/p613-loopback-capture.wav')
with wave.open(str(tone), 'wb') as wav:
    wav.setparams((2, 2, 48000, 0, 'NONE', 'not compressed'))
    for second in range(6):
        block = bytearray()
        for i in range(48000):
            frequency = 440 if second in [1, 2] else 660
            value = int(1536*math.sin(2*math.pi*frequency*i/48000)) if 1 <= second <= 4 else 0
            block.extend(struct.pack('<hh', value, value))
        wav.writeframesraw(block)
recorder = None
result = {'raw_audio_uploaded': False, 'backend': 'PipeWire', 'target': 'p613-microphone'}
try:
    recorder = subprocess.Popen(['pw-record', '--target', 'p613-microphone', '--rate', '16000',
                                 '--channels', '1', '--format', 's16', str(capture)])
    time.sleep(1)
    subprocess.run(['pw-play', '--target', 'p613-speakers', str(tone)], check=True, timeout=15)
    time.sleep(1)
    recorder.send_signal(signal.SIGINT)
    result['recorder_exit'] = recorder.wait(timeout=5)
    with wave.open(str(capture), 'rb') as wav:
        assert wav.getsampwidth() == 2 and wav.getnchannels() == 1
        samples = array.array('h', wav.readframes(wav.getnframes()))
        rate = wav.getframerate()
    result.update({'samples': len(samples), 'sample_rate': rate,
                   'peak': max(map(abs, samples), default=0),
                   'per_second_rms': [round(math.sqrt(sum(x*x for x in samples[i:i+rate])/len(samples[i:i+rate])), 2)
                                      for i in range(0, len(samples), rate)]})
finally:
    if recorder and recorder.poll() is None:
        recorder.kill()
        recorder.wait()
    tone.unlink(missing_ok=True)
    capture.unlink(missing_ok=True)
    result['raw_audio_deleted'] = not capture.exists()
    Path('/tmp/p613-pipewire-mic-result.json').write_text(json.dumps(result, indent=2)+'\n')
print('P613_PIPEWIRE_MIC_TEST_FINISHED', flush=True)
