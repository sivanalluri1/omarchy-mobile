#!/usr/bin/env bash
# Populate Linux storage from Git objects, never from the colliding macOS worktree.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
expected=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["kernel"]["revision"])' "$root/sources.lock.json")
docker run --rm --platform linux/arm64 \
  --mount "type=bind,src=$root/sources/kernel,dst=/seed,readonly" \
  --mount type=volume,src=omarchy-p613-kernel-baseline,dst=/checkout \
  --env "EXPECTED_REVISION=$expected" omarchy-p613-builder:llvm19 bash -c '
set -euo pipefail
if [ ! -d /checkout/kernel ]; then
  git -c safe.directory=/seed clone --no-hardlinks --no-checkout /seed /checkout/kernel
  git -C /checkout/kernel checkout --detach "$EXPECTED_REVISION"
  git -C /checkout/kernel remote set-url origin https://github.com/gta4xlve-dev/android_kernel_samsung_gta4xlve.git
fi
[ "$(git -C /checkout/kernel rev-parse HEAD)" = "$EXPECTED_REVISION" ]
[ -z "$(git -C /checkout/kernel status --porcelain)" ]
printf "Verified clean Linux checkout: %s\n" "$EXPECTED_REVISION"
'
