#!/usr/bin/env bash
# Offline build from the separately fetched, checksum-verified source archive.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/scripts/storage.sh"
require_ssd_storage
mode=${1:-configure}
case "$mode" in configure|build) ;; *) echo 'Usage: build-turnip.sh configure|build' >&2; exit 2;; esac
python3 "$root/scripts/prepare-mesa.py" "$OMARCHY_LINUX_ROOT"
output="$OMARCHY_LINUX_ROOT/build/mesa-turnip"
mkdir -p "$output" "$root/build"
docker run --rm --platform linux/arm64 --network none \
  --mount "type=bind,src=$OMARCHY_LINUX_ROOT/checkout/mesa-turnip,dst=/src,readonly" \
  --mount "type=bind,src=$output,dst=/out" \
  --env "MODE=$mode" --env "JOBS=${JOBS:-4}" \
  omarchy-p613-graphics:debian13 bash -c '
set -euo pipefail
if [ "$MODE" = configure ]; then
  meson setup /out /src --prefix=/opt/p613-gpu --libdir=lib --buildtype=release \
    -Dplatforms= -Dgallium-drivers= -Dvulkan-drivers=freedreno -Dfreedreno-kmds=kgsl \
    -Dglx=disabled -Degl=disabled -Dgbm=disabled -Dopengl=false \
    -Dgles1=disabled -Dgles2=disabled -Dllvm=disabled -Dvideo-codecs= -Dbuild-tests=false
else
  ninja -C /out -j"$JOBS"
  DESTDIR=/out/stage meson install -C /out --no-rebuild
fi
' 2>&1 | tee "$root/build/mesa-turnip-$mode.log"
