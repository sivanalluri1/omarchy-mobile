#!/usr/bin/env bash
# Local build only. No ADB, reboot, packaging, or flashing operations.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
mode=${1:-configure}
case "$mode" in configure|build) ;; *) echo 'Usage: kernel-build.sh configure|build' >&2; exit 2;; esac
expected=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["kernel"]["revision"])' "$root/sources.lock.json")
mkdir -p "$root/build/kernel-baseline"
docker run --rm --platform linux/arm64 \
  --mount "type=volume,src=omarchy-p613-kernel-baseline,dst=/checkout,readonly" \
  --workdir /checkout/kernel \
  --mount "type=volume,src=omarchy-p613-build-baseline,dst=/out" \
  --env "EXPECTED_REVISION=$expected" --env "MODE=$mode" --env "JOBS=${JOBS:-4}" \
  omarchy-p613-builder:llvm19 bash -c '
set -euo pipefail
git config --global --add safe.directory /checkout/kernel
[ "$(git rev-parse HEAD)" = "$EXPECTED_REVISION" ] || { echo "Source revision mismatch" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "Linux source checkout is modified" >&2; exit 1; }
export KBUILD_BUILD_USER=omarchy KBUILD_BUILD_HOST=p613-builder
args=(O=/out ARCH=arm64 LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi-)
if [ "$MODE" = configure ]; then
  make "${args[@]}" vendor/atoll-perf_defconfig
  (cd /out && bash /checkout/kernel/scripts/kconfig/merge_config.sh -m -O /out /out/.config /checkout/kernel/arch/arm64/configs/vendor/gta4xlve.config)
  make "${args[@]}" olddefconfig
else
  [ -f /out/.config ] || { echo "Run configure first" >&2; exit 1; }
  make -j"$JOBS" "${args[@]}" Image dtbs dtbo.img
fi
' 2>&1 | tee "$root/build/kernel-baseline/$mode.log"
