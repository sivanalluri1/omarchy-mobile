#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/scripts/storage.sh"
require_ssd_storage
expected=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["kernel"]["revision"])' "$root/sources.lock.json")
docker run --rm --platform linux/arm64 \
  --mount "type=bind,src=$OMARCHY_LINUX_ROOT/checkout,dst=/checkout,readonly" \
  --env "EXPECTED_REVISION=$expected" omarchy-p613-builder:llvm19 bash -c '
set -euo pipefail
git config --global --add safe.directory /checkout/kernel
[ "$(git -C /checkout/kernel rev-parse HEAD)" = "$EXPECTED_REVISION" ]
[ -z "$(git -C /checkout/kernel status --porcelain)" ]
printf "Verified clean SSD Linux checkout: %s\n" "$EXPECTED_REVISION"
'
