#!/usr/bin/env python3
"""Read-only power snapshot for the validated P613 Samsung kernel.

Samsung sec_battery exposes current in mA; this snapshot normalizes it to uA.
It does not change charger, fuel-gauge, wake-source or suspend settings.
"""
import json
from pathlib import Path
import platform

KERNEL = '4.14.357-openela-perf-g21b136df1533'
if platform.release() != KERNEL:
    raise SystemExit('refusing current-unit conversion on an unvalidated kernel')
battery = Path('/sys/class/power_supply/battery')
def read(name):
    return (battery / name).read_text().strip()
def number(name):
    return int(read(name))

status = read('status')
capacity = number('capacity')
if not 0 <= capacity <= 100:
    raise SystemExit('invalid battery percentage')
print(json.dumps({
    'schema': 1,
    'source': 'p613-sec-battery',
    'status': status,
    'percentage': capacity,
    'voltage_uv': number('voltage_now'),
    'current_ua': number('current_now') * 1000,
    'average_current_ua': number('current_avg') * 1000,
    'temperature_c': number('temp') / 10,
    'health': read('health'),
    'present': bool(number('present')),
    'charging': status == 'Charging',
}, sort_keys=True))
