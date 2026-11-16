#!/usr/bin/env bash
# Separate developer image; preserve the known-good Arch RAM image.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/scripts/storage.sh"
require_ssd_storage
output="$OMARCHY_LINUX_ROOT/build/arch-omarchy"
mkdir -p "$output"
case "${1:-prepare}" in
prepare)
  [ ! -e "$output/root.img" ] || { echo 'Existing image; use resume' >&2; exit 1; }
  cp -c "$OMARCHY_LINUX_ROOT/build/arch-ram/arch-ram.img" "$output/root.img"
  ;;
resume) [ -f "$output/root.img" ] && [ ! -e "$output/root.squashfs" ];;
*) echo 'Usage: build-omarchy-root.sh prepare|resume' >&2; exit 2;;
esac
docker run --rm --platform linux/arm64 --cap-add SYS_ADMIN \
  --device-cgroup-rule 'b 7:* rwm' --device-cgroup-rule 'c 10:237 rwm' \
  --mount "type=bind,src=$root,dst=/project,readonly" \
  --mount "type=bind,src=$root/work/omarchy-integration,dst=/inputs,readonly" \
  --mount "type=bind,src=$OMARCHY_LINUX_ROOT/checkout/omarchy-mobile,dst=/upstream,readonly" \
  --mount "type=bind,src=$OMARCHY_LINUX_ROOT/build/wayland-runtime-final,dst=/runtime,readonly" \
  --mount "type=bind,src=$OMARCHY_LINUX_ROOT/build/mesa-zink-fd-fix/stage/opt/p613-gpu/lib/libvulkan_freedreno.so,dst=/mesa-fixed/libvulkan_freedreno.so,readonly" \
  --mount "type=bind,src=$output,dst=/out" \
  --mount "type=bind,src=$root/work/hardware-test-10,dst=/radio-inputs,readonly" \
  --mount "type=bind,src=$OMARCHY_LINUX_ROOT/build/radio-tools,dst=/radio-tools,readonly" \
  omarchy-p613-ram-root:debian13 bash /project/scripts/assemble-omarchy-root-inside.sh \
  2>&1 | tee "$root/build/omarchy-root-build.log"
