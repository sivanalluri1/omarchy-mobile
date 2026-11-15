#!/usr/bin/env python3
"""Fetch pinned AOSP Python tools and verify decoded source hashes."""
import base64
import hashlib
import json
from pathlib import Path
import urllib.request
root = Path(__file__).resolve().parent.parent
out = root / 'work/tools/aosp'
out.mkdir(parents=True, exist_ok=True)
for tool in json.loads((root / 'aosp-tools.lock.json').read_text()):
    target = out / tool['name']
    if target.exists():
        data = target.read_bytes()
    else:
        with urllib.request.urlopen(tool['base64_url'], timeout=60) as response:
            data = base64.b64decode(response.read())
    if hashlib.sha256(data).hexdigest() != tool['sha256']:
        raise SystemExit(f"Tool hash mismatch: {tool['name']}")
    if not target.exists():
        target.write_bytes(data)
    print(f"Verified {tool['name']}")
