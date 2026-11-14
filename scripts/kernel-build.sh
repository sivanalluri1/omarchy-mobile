#!/usr/bin/env bash
# Local build only. No ADB, reboot, packaging, or flashing operations.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
mode=${1:-configure}
case "$mode" in configure|build) ;; *) echo 'Usage: kernel-build.sh configure|build' >&2; exit 2;; esac
expected=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["kernel"]["revision"])' "$root/sources.lock.json")
actual=$(git -C "$root/sources/kernel" rev-parse HEAD)
[ "$actual" = "$expected" ] || { echo 'Kernel source revision mismatch' >&2; exit 1; }
[ -z "$(git -C "$root/sources/kernel" status --porcelain)" ] || { echo 'Kernel source has modifications' >&2; exit 1; }
mkdir -p "$root/build/kernel-baseline"
docker run --rm --platform linux/arm64 \
  --mount "type=bind,src=$root/sources/kernel,dst=/src,readonly" \
  --mount "type=bind,src=$root/build/kernel-baseline,dst=/out" \
  --env "MODE=$mode" --env "JOBS=${JOBS:-4}" \
  omarchy-p613-builder:llvm19 bash -c '
set -euo pipefail
export KBUILD_BUILD_USER=omarchy KBUILD_BUILD_HOST=p613-builder
args=(O=/out ARCH=arm64 LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi-)
if [ "$MODE" = configure ]; then
  make "${args[@]}" vendor/atoll-perf_defconfig
  bash scripts/kconfig/merge_config.sh -m -O /out /out/.config arch/arm64/configs/vendor/gta4xlve.config
  make "${args[@]}" olddefconfig
else
  [ -f /out/.config ] || { echo "Run configure first" >&2; exit 1; }
  make -j"$JOBS" "${args[@]}" Image dtbs dtbo.img
fi
' 2>&1 | tee "$root/build/kernel-baseline/$mode.log"
