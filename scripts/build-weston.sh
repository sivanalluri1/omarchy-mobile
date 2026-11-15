#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/scripts/storage.sh"
require_ssd_storage
mode=${1:-configure}
case "$mode" in configure|build) ;; *) echo 'Usage: build-weston.sh configure|build' >&2; exit 2;; esac
python3 "$root/scripts/prepare-weston.py" "$OMARCHY_LINUX_ROOT"
output="$OMARCHY_LINUX_ROOT/build/weston"
mkdir -p "$output"
docker run --rm --platform linux/arm64 --network none \
  --mount "type=bind,src=$OMARCHY_LINUX_ROOT/checkout/weston,dst=/src,readonly" \
  --mount "type=bind,src=$output,dst=/out" \
  --env "MODE=$mode" --env "JOBS=${JOBS:-4}" \
  omarchy-p613-weston:debian13 bash -c '
set -euo pipefail
if [ "$MODE" = configure ]; then
  meson setup /out /src --prefix=/usr --libdir=lib/aarch64-linux-gnu --buildtype=release \
    -Dbackend-drm=true -Dbackend-drm-screencast-vaapi=false -Dbackend-default=drm \
    -Dbackend-headless=false -Dbackend-pipewire=false -Dbackend-rdp=false \
    -Dbackend-vnc=false -Dbackend-wayland=false -Dbackend-x11=false \
    -Drenderer-gl=true -Dxwayland=false -Dsystemd=false -Dremoting=false -Dpipewire=false \
    -Dscreenshare=false -Dshell-desktop=false -Dshell-fullscreen=false -Dshell-ivi=false \
    -Dshell-kiosk=true -Dcolor-management-lcms=false -Dimage-jpeg=false -Dimage-webp=false \
    -Dtools= -Ddemo-clients=false -Dsimple-clients=egl -Dwcap-decode=false -Dtests=false -Ddoc=false
else
  ninja -C /out -j"$JOBS"
  DESTDIR=/out/stage meson install -C /out --no-rebuild
fi
' 2>&1 | tee "$root/build/weston-$mode.log"
