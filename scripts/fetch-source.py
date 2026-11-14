#!/usr/bin/env python3
"""Fetch a pinned source into ignored sources/. Defaults to kernel only."""
import json
from pathlib import Path
import subprocess
import sys
root = Path(__file__).resolve().parent.parent
sources = json.loads((root / "sources.lock.json").read_text())
names = sys.argv[1:] or ["kernel"]
if any(name not in sources for name in names):
    raise SystemExit("Choose kernel, device, or vendor")
for name in names:
    spec = sources[name]
    dest = root / "sources" / name
    dest.parent.mkdir(exist_ok=True)
    if not dest.exists():
        subprocess.run(["git", "init", str(dest)], check=True)
        subprocess.run(["git", "-C", str(dest), "remote", "add", "origin", spec["url"]], check=True)
    remote = subprocess.check_output(["git", "-C", str(dest), "remote", "get-url", "origin"], text=True).strip()
    if remote != spec["url"]:
        raise SystemExit(f"Unexpected origin in {dest}")
    dirty = subprocess.check_output(["git", "-C", str(dest), "status", "--porcelain"], text=True)
    if dirty:
        raise SystemExit(f"Refusing to change modified checkout: {dest}")
    subprocess.run(["git", "-C", str(dest), "fetch", "--depth=1", "origin", spec["revision"]], check=True)
    subprocess.run(["git", "-C", str(dest), "checkout", "--detach", spec["revision"]], check=True)
    actual = subprocess.check_output(["git", "-C", str(dest), "rev-parse", "HEAD"], text=True).strip()
    if actual != spec["revision"]:
        raise SystemExit(f"Revision mismatch: {dest}")
    print(f"Verified {name}: {actual}")
