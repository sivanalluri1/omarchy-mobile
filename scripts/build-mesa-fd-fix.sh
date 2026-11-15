#!/usr/bin/env bash
# Preserve the working display bridge; patch only the allocation-fd ownership.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/scripts/storage.sh"
require_ssd_storage
python3 "$root/scripts/prepare-mesa.py" "$OMARCHY_LINUX_ROOT"
output="$OMARCHY_LINUX_ROOT/build/mesa-zink-fd-fix"
if [ ! -e "$output" ]; then
  cp -cpR "$OMARCHY_LINUX_ROOT/build/mesa-zink-bridge" "$output"
fi
python3 - "$root" "$OMARCHY_LINUX_ROOT" "$output" <<'PY'
import hashlib,json,pathlib,subprocess,sys
root,base,out=map(pathlib.Path,sys.argv[1:])
lock=json.loads((root/'mesa-fd-fix.lock.json').read_text())
original=base/'checkout/mesa-turnip'/lock['source_file']
patch=root/lock['patch']
assert hashlib.sha256(original.read_bytes()).hexdigest()==lock['upstream_file_sha256']
assert hashlib.sha256(patch.read_bytes()).hexdigest()==lock['patch_sha256']
overlay=out/'source-overlay'
override=overlay/lock['source_file']
override.parent.mkdir(parents=True,exist_ok=True)
override.write_bytes(original.read_bytes())
subprocess.run(['patch','-p1','--batch','--fuzz=0','-i',str(patch)],cwd=overlay,check=True)
assert hashlib.sha256(override.read_bytes()).hexdigest()==lock['patched_file_sha256']
zink=json.loads((root/'mesa-display.lock.json').read_text())
assert hashlib.sha256((overlay/zink['source_file']).read_bytes()).hexdigest()==zink['patched_file_sha256']
PY
docker run --rm --platform linux/arm64 --network none \
  --mount "type=bind,src=$OMARCHY_LINUX_ROOT/checkout/mesa-turnip,dst=/src,readonly" \
  --mount "type=bind,src=$output/source-overlay/src/gallium/drivers/zink/zink_screen.c,dst=/src/src/gallium/drivers/zink/zink_screen.c,readonly" \
  --mount "type=bind,src=$output/source-overlay/src/freedreno/vulkan/tu_knl_kgsl.cc,dst=/src/src/freedreno/vulkan/tu_knl_kgsl.cc,readonly" \
  --mount "type=bind,src=$output,dst=/out" --env "JOBS=${JOBS:-4}" \
  omarchy-p613-graphics:debian13 bash -c '
set -euo pipefail
ninja -C /out -j"$JOBS"
DESTDIR=/out/stage meson install -C /out --no-rebuild
' 2>&1 | tee "$root/build/mesa-fd-fix-build.log"
python3 - "$root" "$output" <<'PY'
import hashlib,json,pathlib,sys
root,out=map(pathlib.Path,sys.argv[1:])
p=out/'stage/opt/p613-gpu/lib/libvulkan_freedreno.so'
r={'mesa_revision':json.loads((root/'mesa.lock.json').read_text())['revision'],
   'patch':json.loads((root/'mesa-fd-fix.lock.json').read_text()),
   'library_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'library_bytes':p.stat().st_size,'tablet_tested':False}
(out/'validation.json').write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps(r,indent=2))
PY
