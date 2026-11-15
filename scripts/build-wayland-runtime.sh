#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/scripts/storage.sh"
require_ssd_storage
variant=${1:-baseline}
case "$variant" in baseline|patched|bridge) ;; *) echo 'Usage: build-wayland-runtime.sh baseline|patched|bridge' >&2; exit 2;; esac
extra=()
output="$OMARCHY_LINUX_ROOT/build/wayland-runtime"
mesa_output="$OMARCHY_LINUX_ROOT/build/mesa-zink"
if [ "$variant" = patched ] || [ "$variant" = bridge ]; then
  output="$output-$variant"
  extra=(--mount "type=bind,src=$OMARCHY_LINUX_ROOT/build/weston,dst=/weston,readonly" --env USE_PATCHED_WESTON=1)
fi
if [ "$variant" = bridge ]; then mesa_output="$OMARCHY_LINUX_ROOT/build/mesa-zink-bridge"; fi
if [ -n "${2:-}" ]; then
  [[ "$2" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo 'Invalid bundle name' >&2; exit 2; }
  output="$OMARCHY_LINUX_ROOT/build/wayland-runtime-$2"
fi
# Refuse overwriting an existing bundle; preserve previous test evidence.
[ ! -e "$output/manifest.json" ] || { echo 'Existing runtime: choose a fresh output before rebuilding' >&2; exit 1; }
mkdir -p "$output"
docker run --rm --platform linux/arm64 --network none "${extra[@]}" \
  --mount "type=bind,src=$root,dst=/project,readonly" \
  --mount "type=bind,src=$OMARCHY_LINUX_ROOT/build/graphics-probes,dst=/graphics-probes,readonly" \
  --mount "type=bind,src=$mesa_output,dst=/mesa,readonly" \
  --mount "type=bind,src=$OMARCHY_LINUX_ROOT/build/gpu-probes,dst=/probes,readonly" \
  --mount "type=bind,src=$output,dst=/runtime" \
  omarchy-p613-graphics:debian13 python3 /project/scripts/assemble-wayland-runtime.py
