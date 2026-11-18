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
  sh -c 'gcc --version > /out/compiler.txt; exec gcc -static -O2 -Wall -Wextra -Werror /src/p613-suspend-test.c -o /out/p613-suspend-test'
shasum -a 256 "$out/p613-suspend-test"

python3 - "$root" "$out" <<'PYMETA'
from pathlib import Path
import datetime, hashlib, json, subprocess, sys
root, out = map(Path, sys.argv[1:])
binary = out/'p613-suspend-test'
record = {
    'built_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'kernel': '4.14.357-openela-perf-g21b136df1533',
    'compiler': (out/'compiler.txt').read_text().splitlines()[0],
    'container_image': subprocess.check_output(['docker','image','inspect','--format','{{.Id}}','omarchy-p613-graphics:debian13'],text=True).strip(),
    'flags': '-static -O2 -Wall -Wextra -Werror',
    'source_sha256': hashlib.sha256((root/'native/p613-suspend-test.c').read_bytes()).hexdigest(),
    'binary_sha256': hashlib.sha256(binary.read_bytes()).hexdigest(),
    'bytes': binary.stat().st_size,
    'untimed_mode': 'sleep; leaves RTC unchanged',
}
(root/'docs/build-records/power-probe-build.json').write_text(json.dumps(record,indent=2)+'\n')
PYMETA
