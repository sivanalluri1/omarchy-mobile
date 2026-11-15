#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/scripts/storage.sh"
require_ssd_storage
mode=${1:-bootstrap}
case "$mode" in bootstrap|packages|finalize|inspect) ;; *) exit 2;; esac
if [ "$(docker inspect -f '{{.State.Running}}' p613-arch-nbd-test 2>/dev/null || true)" = true ]; then
  echo 'Stop the NBD export before modifying/inspecting its filesystem image' >&2; exit 1
fi
output="$OMARCHY_LINUX_ROOT/build/arch-userspace"
mkdir -p "$output" "$root/build"
docker run --rm --platform linux/arm64 --cap-add SYS_ADMIN \
  --device-cgroup-rule 'b 7:* rwm' --device-cgroup-rule 'c 10:237 rwm' \
  --mount "type=bind,src=$root/scripts,dst=/project/scripts,readonly" \
  --mount "type=bind,src=$root/configs,dst=/project/configs,readonly" \
  --mount "type=bind,src=$root/native,dst=/project/native,readonly" \
  --mount "type=bind,src=$OMARCHY_LINUX_ROOT/build/wayland-runtime-final/gpu/lib/libdisplay-info.so.2,dst=/compat/libdisplay-info.so.2,readonly" \
  --mount "type=bind,src=$OMARCHY_LINUX_ROOT/build/mesa-zink-bridge/stage/opt/p613-gpu,dst=/gpu-stage,readonly" \
  --mount "type=bind,src=$root/work/userspace,dst=/input,readonly" \
  --mount "type=bind,src=$output,dst=/out" \
  omarchy-p613-userspace:debian13 bash /project/scripts/arch-rootfs-inside.sh "$mode" \
  2>&1 | tee "$root/build/arch-rootfs-$mode.log"
