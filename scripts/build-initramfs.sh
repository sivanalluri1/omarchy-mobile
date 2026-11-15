#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/scripts/storage.sh"
require_ssd_storage
keys="$OMARCHY_ARTIFACT_ROOT/work/keys"
out="$OMARCHY_LINUX_ROOT/build/initramfs"
mkdir -p "$keys" "$out"
chmod 700 "$keys"
if [ ! -f "$keys/client_ed25519" ]; then
  ssh-keygen -q -t ed25519 -N '' -C p613-linux-bringup -f "$keys/client_ed25519"
fi
docker run --rm --network none --platform linux/arm64 \
  --mount "type=bind,src=$root/initramfs,dst=/project-init,readonly" \
  --mount "type=bind,src=$root/scripts/assemble-initramfs.sh,dst=/assemble.sh,readonly" \
  --mount "type=bind,src=$keys,dst=/keys" \
  --mount "type=bind,src=$out,dst=/out" \
  omarchy-p613-initramfs:debian13 bash /assemble.sh
