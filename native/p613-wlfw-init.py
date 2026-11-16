#!/usr/bin/env python3
"""Bounded RAM-only WLFW board-data initialization for the pinned P613 kernel.

Message IDs and TLVs follow this kernel's wlan_firmware_service_v01.{c,h}.
No calibration files, MAC addresses or block devices are written.
"""
import argparse
import hashlib
import os
from pathlib import Path
import socket
import struct
import time


def tlv(kind, value):
    return struct.pack('<BH', kind, len(value)) + value


def decode_tlvs(data):
    result = {}
    while data:
        if len(data) < 3:
            raise ValueError('Truncated TLV header')
        kind, size = struct.unpack('<BH', data[:3])
        if len(data) < 3 + size:
            raise ValueError('Truncated TLV value')
        result[kind] = data[3:3+size]
        data = data[3+size:]
    return result


p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--initialize', action='store_true', required=True)
p.add_argument('--bdf', type=Path, default=Path('/tmp/p613-bdwlan.bin'))
a = p.parse_args()
assert os.geteuid() == 0
assert os.uname().release == '4.14.357-openela-perf-g21b136df1533'
assert Path('/etc/p613-bringup').is_file()
bdf = a.bdf.read_bytes()
assert hashlib.sha256(bdf).hexdigest() == 'a3b0033ac112be147d9d61fdfcf7401a45ba4120bdb770dd9fb97c45bd72516d'
s = socket.socket(socket.AF_QIPCRTR, socket.SOCK_DGRAM)
s.bind((1, 0))
s.settimeout(5)
s.sendto(struct.pack('<5I', 10, 69, 1, 0, 0), (1, 0xfffffffe))
deadline = time.monotonic() + 10
peer = None
while time.monotonic() < deadline:
    data, source = s.recvfrom(8192)
    if len(data) < 20:
        continue
    command, service, instance, node, port = struct.unpack('<5I', data[:20])
    if command == 4 and service == 69 and instance & 255 == 1:
        peer = (node, port)
        break
if peer is None:
    raise RuntimeError('No WLFW service')
transaction = 0


def request(message, body=b''):
    global transaction
    transaction += 1
    s.sendto(struct.pack('<BHHH', 0, transaction, message, len(body))+body, peer)
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        data, source = s.recvfrom(8192)
        if source != peer or len(data) < 7:
            continue
        kind, txn, msg, size = struct.unpack('<BHHH', data[:7])
        if len(data) != size + 7:
            raise ValueError('Malformed QMI message size')
        if kind == 4:
            print(f'WLFW_INDICATION message=0x{msg:04x}', flush=True)
            continue
        if kind != 2 or txn != transaction or msg != message:
            continue
        values = decode_tlvs(data[7:])
        result, error = struct.unpack('<HH', values[2])
        if result:
            raise RuntimeError(f'WLFW message=0x{message:04x} result={result} error={error}')
        print(f'WLFW_RESPONSE message=0x{message:04x} success=true', flush=True)
        return values
    raise TimeoutError('No matching QMI response')


# DMON complements the kernel's KNEL client without replacing its MSA setup.
request(0x20, tlv(0x10, b'\x01') + tlv(0x15, struct.pack('<I', 0x444d4f4e)))
cap = request(0x24)
board_id = struct.unpack('<I', cap[0x11])[0] if 0x11 in cap else 0xff
if board_id != 0xff:
    raise RuntimeError(f'Board-specific selection required for board_id={board_id}')
print(f'WLFW_BDF bytes={len(bdf)} sha256={hashlib.sha256(bdf).hexdigest()}', flush=True)
for segment, offset in enumerate(range(0, len(bdf), 6144)):
    chunk = bdf[offset:offset+6144]
    body = tlv(1, b'\x01') + tlv(0x10, struct.pack('<I', board_id))
    body += tlv(0x11, struct.pack('<I', len(bdf)))
    body += tlv(0x12, struct.pack('<I', segment))
    body += tlv(0x13, struct.pack('<H', len(chunk))+chunk)
    body += tlv(0x14, bytes([offset+len(chunk) == len(bdf)]))
    body += tlv(0x15, b'\x00')  # binary BDF
    request(0x25, body)
# No persistent calibration cache is supplied. Report zero cached entries.
request(0x26, tlv(1, b'\x00'))
print('WLFW_INITIALIZATION_COMPLETE', flush=True)
