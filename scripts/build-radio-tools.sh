#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/scripts/storage.sh"
require_ssd_storage
python3 - "$root/radio-sources.lock.json" "$OMARCHY_LINUX_ROOT/checkout" <<'PY'
import json,sys,subprocess
from pathlib import Path
for name, source in json.load(open(sys.argv[1])).items():
    repo=Path(sys.argv[2])/name
    assert subprocess.check_output(['git','-C',str(repo),'rev-parse','HEAD'],text=True).strip()==source['revision']
    assert not subprocess.check_output(['git','-C',str(repo),'status','--porcelain'],text=True).strip()
PY
out="$OMARCHY_LINUX_ROOT/build/radio-tools"
mkdir -p "$out"
docker run --rm --network none \
  --mount "type=bind,src=$OMARCHY_LINUX_ROOT/checkout,dst=/src,readonly" \
  --mount "type=bind,src=$root/patches/radio,dst=/patches,readonly" \
  --mount "type=bind,src=$out,dst=/out" \
  omarchy-p613-graphics:debian13 sh -c '
set -eu
cp /src/pd-mapper/pd-mapper.c /out/pd-mapper.c
cp /src/tqftpserv/translate.c /out/translate.c
patch --batch /out/pd-mapper.c /patches/0001-pd-mapper-explicit-pil-firmware.patch
patch --batch /out/translate.c /patches/0002-tqftpserv-explicit-pil-firmware.patch
cd /src/qrtr
gcc -static -O2 -Wall -Ilib lib/logging.c src/addr.c src/ns.c src/map.c src/hash.c src/waiter.c src/util.c -o /out/qrtr-ns
gcc -static -O2 -Wall -Ilib lib/logging.c src/lookup.c src/util.c -o /out/qrtr-lookup
common="/src/qrtr/lib/qrtr.c /src/qrtr/lib/qmi.c /src/qrtr/lib/logging.c"
gcc -O2 -Wall -I/src/qrtr/lib -I/src/qrtr/src /src/rmtfs/qmi_rmtfs.c /src/rmtfs/rmtfs.c /src/rmtfs/rproc.c /src/rmtfs/sharedmem.c /src/rmtfs/storage.c /src/rmtfs/util.c $common -ludev -lpthread -o /out/rmtfs
gcc -static -O2 -Wall -I/src/pd-mapper -I/src/qrtr/lib -I/src/qrtr/src /out/pd-mapper.c /src/pd-mapper/assoc.c /src/pd-mapper/json.c /src/pd-mapper/servreg_loc.c /src/pd-mapper/lzma_decomp.c $common -llzma -o /out/pd-mapper
gcc -static -O2 -Wall -I/src/tqftpserv -I/src/qrtr/lib -I/src/qrtr/src /src/tqftpserv/tqftpserv.c /out/translate.c $common -o /out/tqftpserv
sha256sum /out/qrtr-ns /out/qrtr-lookup /out/rmtfs /out/pd-mapper /out/tqftpserv
'
