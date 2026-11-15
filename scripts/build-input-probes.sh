#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/scripts/storage.sh"
require_ssd_storage
output="$OMARCHY_LINUX_ROOT/build/input-probes"
mkdir -p "$output"
docker run --rm --network none \
  --mount "type=bind,src=$root/native,dst=/src,readonly" \
  --mount "type=bind,src=$output,dst=/out" \
  omarchy-p613-input:debian13 bash -c '
set -euo pipefail
gcc -O2 -Wall -Wextra -Werror /src/input-probe.c -o /out/input-probe $(pkg-config --cflags --libs libinput libudev)
sha256sum /out/input-probe
'
