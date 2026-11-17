#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/scripts/storage.sh"
require_ssd_storage
out="$OMARCHY_LINUX_ROOT/build/power-tools"
mkdir -p "$out"
docker run --rm --network none \
  --mount "type=bind,src=$root/native,dst=/src,readonly" \
  --mount "type=bind,src=$out,dst=/out" \
  omarchy-p613-graphics:debian13 \
  gcc -static -O2 -Wall -Wextra -Werror /src/p613-suspend-test.c -o /out/p613-suspend-test
shasum -a 256 "$out/p613-suspend-test"
