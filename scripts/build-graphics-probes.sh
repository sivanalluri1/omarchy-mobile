#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/scripts/storage.sh"
require_ssd_storage
output="$OMARCHY_LINUX_ROOT/build/graphics-probes"
mkdir -p "$output"
docker run --rm --platform linux/arm64 \
  --mount "type=bind,src=$root/native,dst=/native,readonly" \
  --mount "type=bind,src=$OMARCHY_LINUX_ROOT/checkout/kernel/include/uapi/linux,dst=/kernel-uapi,readonly" \
  --mount "type=bind,src=$output,dst=/out" \
  omarchy-p613-graphics:debian13 bash -c '
set -euo pipefail
gcc -static -O2 -Wall -Wextra -Werror $(pkg-config --cflags libdrm) \
  -iquote /kernel-uapi /native/graphics-probe.c -o /out/graphics-probe \
  $(pkg-config --libs --static libdrm)
gcc -static -O2 -Wall -Wextra -Werror $(pkg-config --cflags libdrm) \
  /native/display-test.c -o /out/display-test $(pkg-config --libs --static libdrm)
file /out/graphics-probe /out/display-test
# No devices exist in this container; failure here is expected and checked.
if /out/graphics-probe; then echo "Unexpected device access" >&2; exit 1; fi
sha256sum /out/graphics-probe /out/display-test
'
