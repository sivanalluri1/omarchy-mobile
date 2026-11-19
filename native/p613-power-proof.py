#!/usr/bin/env python3
"""Read-only on-tablet Power validation view; does not control the supervisor."""
import json
from pathlib import Path
import time

last_sleep = None
while True:
    try:
        state = json.loads(Path('/run/p613-power-button.json').read_text())
    except (OSError, ValueError):
        state = {'phase': 'waiting for supervisor'}
    if state.get('phase') == 'resumed' and state.get('suspended_seconds') is not None:
        last_sleep = state['suspended_seconds']
    alarm = 'unavailable'
    try:
        for line in Path('/proc/driver/rtc').read_text().splitlines():
            if line.startswith('alarm_IRQ'):
                alarm = line.split(':', 1)[1].strip()
    except OSError:
        pass
    measured = 'not measured yet' if last_sleep is None else f'{last_sleep:.3f} seconds'
    print('\033[2J\033[HNative Power validation — SM-P613\n',
          'Supervisor: '+str(state.get('phase'))+'\n',
          'LAST DEEP SLEEP: '+measured+'\n',
          'RTC ALARM ENABLED: '+alarm+'\n',
          ('DETAIL: '+str(state.get('detail'))+'\n' if state.get('detail') else '')+'\n',
          'After waking, report LAST DEEP SLEEP.\n',
          'Closing this window leaves Power controls running.\n', sep='', flush=True)
    time.sleep(1)
