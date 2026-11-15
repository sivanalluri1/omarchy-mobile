#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/scripts/storage.sh"
require_ssd_storage
image="$OMARCHY_LINUX_ROOT/build/arch-userspace/arch-root.img"
[ "$(docker inspect -f '{{.State.Running}}' p613-arch-nbd-test 2>/dev/null || true)" != true ] || exit 1
docker run --rm --read-only --network none --cap-drop ALL \
  --mount "type=bind,src=$image,dst=/image/arch-root.img,readonly" \
  omarchy-p613-userspace:debian13 bash -c '
set -euo pipefail
e2fsck -fn /image/arch-root.img
qemu-nbd --persistent --shared=1 --read-only --format=raw \
  --export-name=arch-root-offline-test --bind=127.0.0.1 --port=10809 /image/arch-root.img &
server=$!
trap '\''kill "$server"; wait "$server" || true'\'' EXIT
sleep 1
qemu-nbd --list --bind=127.0.0.1 --port=10809
' 2>&1 | tee "$root/build/arch-root-image-validation.log"
