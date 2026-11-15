#!/usr/bin/env bash
# Export only this developer filesystem image, read-only, on the private USB IP.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
source "$root/scripts/storage.sh"
require_ssd_storage
case "${1:-}" in
start)
  ifconfig en5 | rg -q 'inet 192\.168\.77\.2 ' || { echo 'Native USB DHCP interface is not ready' >&2; exit 1; }
  image="$OMARCHY_LINUX_ROOT/build/arch-userspace/arch-root.img"
  [ -f "$image" ] || exit 1
  mkdir -p "$root/work/keys"
  if [ ! -f "$root/work/keys/nbd-export.name" ]; then
    (umask 077; python3 -c 'import secrets; print(secrets.token_hex(24))' > "$root/work/keys/nbd-export.name")
  fi
  export_name=$(cat "$root/work/keys/nbd-export.name")
  [[ "$export_name" =~ ^[0-9a-f]{48}$ ]] || exit 1
  docker run --detach --name p613-arch-nbd-test --read-only --cap-drop ALL \
    --security-opt no-new-privileges --publish 192.168.77.2:10809:10809 \
    --mount "type=bind,src=$image,dst=/image/arch-root.img,readonly" \
    omarchy-p613-userspace:debian13 qemu-nbd --persistent --shared=1 --read-only \
      --format=raw --export-name="$export_name" --port=10809 --bind=0.0.0.0 /image/arch-root.img
  ;;
stop)
  # The tablet must unmount the filesystem and disconnect /dev/nbd0 first.
  docker stop p613-arch-nbd-test
  docker rm p613-arch-nbd-test
  ;;
*) echo 'Usage: serve-arch-root.sh start|stop' >&2; exit 2;;
esac
