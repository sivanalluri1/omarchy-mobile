#!/usr/bin/env python3
"""Reconstruct a full new-block-only Android transfer image offline.

Input is already decompressed .new.dat. Refuses incremental operations and
existing outputs. Does not mount images or access devices.
"""
import argparse
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('transfer_list', type=Path)
p.add_argument('new_dat', type=Path)
p.add_argument('output', type=Path)
a = p.parse_args()
lines = a.transfer_list.read_text().splitlines()
if lines[0] != '4' or lines[2:4] != ['0', '0']:
    p.error('Only version 4 full images without stash blocks are supported')
ranges = []
for line in lines[4:]:
    operation, encoded = line.split()
    if operation != 'new':
        p.error('Only new operations are supported')
    numbers = list(map(int, encoded.split(',')))
    if numbers[0] != len(numbers) - 1 or numbers[0] % 2:
        p.error('Malformed block range')
    ranges.extend(zip(numbers[1::2], numbers[2::2]))
end = 0
for start, stop in ranges:
    if start < end or stop <= start:
        p.error('Overlapping, unordered or empty range')
    end = stop
if sum(stop-start for start, stop in ranges) != int(lines[1]):
    p.error('Transfer block count mismatch')
if a.new_dat.stat().st_size != int(lines[1]) * 4096:
    p.error('Data size mismatch')
with a.new_dat.open('rb') as src, a.output.open('xb') as dst:
    for start, stop in ranges:
        dst.seek(start * 4096)
        remaining = (stop-start) * 4096
        while remaining:
            data = src.read(min(remaining, 1024*1024))
            if not data:
                raise RuntimeError('Unexpected end of input')
            dst.write(data)
            remaining -= len(data)
print(f'Reconstructed {a.output.stat().st_size} bytes')
