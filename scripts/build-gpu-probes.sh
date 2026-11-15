#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/scripts/storage.sh"
require_ssd_storage
output="$OMARCHY_LINUX_ROOT/build/gpu-probes"
mkdir -p "$output"
docker run --rm --platform linux/arm64 --network none \
  --mount "type=bind,src=$root/native,dst=/native,readonly" \
  --mount "type=bind,src=$output,dst=/out" \
  omarchy-p613-graphics:debian13 bash -c '
set -euo pipefail
glslangValidator -V --target-env vulkan1.1 /native/gpu-compute.comp -o /out/gpu-compute.spv
python3 - <<'\''PY'\''
import struct,pathlib
b=pathlib.Path("/out/gpu-compute.spv").read_bytes()
pathlib.Path("/out/gpu-compute-spv.h").write_text("static const uint32_t compute_spv[]={"+",".join(hex(x) for x in struct.unpack("<%dI"%(len(b)//4),b))+"};\n")
PY
gcc -O2 -Wall -Wextra -Werror -I/out /native/gpu-compute.c -lvulkan -o /out/gpu-compute
gcc -O2 -Wall -Wextra -Werror /native/gpu-render.c -lEGL -lGLESv2 -o /out/gpu-render
gcc -O2 -Wall -Wextra -Werror /native/gbm-probe.c -lgbm -lEGL -lGLESv2 -o /out/gbm-probe
file /out/gpu-compute /out/gpu-render /out/gbm-probe
sha256sum /out/gpu-compute /out/gpu-compute.spv /out/gpu-render /out/gbm-probe
'
