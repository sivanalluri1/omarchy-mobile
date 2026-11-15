#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/scripts/storage.sh"
require_ssd_storage
[ "$(docker inspect -f '{{.State.Running}}' p613-arch-nbd-test 2>/dev/null || true)" != true ] || exit 1
output="$OMARCHY_LINUX_ROOT/build/arch-ram"
mkdir -p "$output"
case "${1:-prepare}" in
prepare)
  [ ! -e "$output/arch-ram.img" ] || { echo 'Existing preparation image; use resume to continue it' >&2; exit 1; }
  cp -c "$OMARCHY_LINUX_ROOT/build/arch-userspace/arch-root.img" "$output/arch-ram.img"
  ;;
resume) [ -f "$output/arch-ram.img" ] && [ ! -e "$output/arch-root.squashfs" ] || exit 1;;
*) echo 'Usage: build-arch-ram-root.sh prepare|resume' >&2; exit 2;;
esac
docker run --rm --platform linux/arm64 --network none --cap-add SYS_ADMIN \
  --device-cgroup-rule 'b 7:* rwm' --device-cgroup-rule 'c 10:237 rwm' \
  --mount "type=bind,src=$root,dst=/project,readonly" \
  --mount "type=bind,src=$root/work/hardware-test-02/firmware,dst=/firmware,readonly" \
  --mount "type=bind,src=$output,dst=/out" \
  omarchy-p613-ram-root:debian13 bash /project/scripts/assemble-arch-ram-inside.sh \
  2>&1 | tee "$root/build/arch-ram-root-build.log"
