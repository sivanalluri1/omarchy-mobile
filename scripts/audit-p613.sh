#!/usr/bin/env bash
# Read-only device inspection. Does not request root, reboot, or write device files.
set -eu
command -v adb >/dev/null || { echo 'Install Android platform-tools and add adb to PATH.' >&2; exit 1; }
serial="${1:-}"
if [ -z "$serial" ]; then
  serial=$(adb devices | awk 'NR>1 && $2=="device" {print $1}')
fi
[ -n "$serial" ] || { echo 'Connect the tablet, enable USB debugging, and accept its authorization prompt.' >&2; exit 1; }
case "$serial" in *$'\n'*) echo 'Multiple devices: pass one serial as the first argument.' >&2; exit 1;; esac
model=$(adb -s "$serial" shell getprop ro.product.model | tr -d '\r')
[ "$model" = SM-P613 ] || { echo "Expected SM-P613, found: $model" >&2; exit 1; }
out="p613-audit-$(date +%Y%m%d-%H%M%S)"
mkdir -m 700 "$out"
collect() {
  name=$1; shift
  adb -s "$serial" shell "$@" >"$out/$name.txt" 2>&1 || true
}
collect identity 'for p in ro.product.model ro.product.device ro.product.board ro.board.platform ro.build.display.id ro.lineage.version ro.boot.bootloader ro.boot.slot_suffix ro.boot.verifiedbootstate; do echo "$p=$(getprop "$p")"; done; uname -a'
collect partitions 'cat /proc/partitions; ls -l /dev/block/by-name /dev/block/bootdevice/by-name; cat /proc/mounts'
collect graphics 'ls -l /dev/dri /dev/graphics /dev/kgsl*; ls -l /sys/class/drm; cat /sys/class/graphics/fb0/name /sys/class/graphics/fb0/modes; dumpsys SurfaceFlinger | head -n 100'
collect input 'cat /proc/bus/input/devices; getevent -lp'
collect usb 'getprop sys.usb.config; getprop sys.usb.controller; ls /sys/class/udc; ls /config/usb_gadget'
collect firmware 'ls -l /vendor/firmware /vendor/firmware_mnt/image; ls -l /vendor/lib64/egl /vendor/lib64/hw'
collect power 'for d in /sys/class/power_supply/*; do echo "$d"; cat "$d/type" "$d/status" "$d/capacity"; done'
# exec-out preserves the gzip bytes; permission failures are recorded separately.
if ! adb -s "$serial" exec-out cat /proc/config.gz >"$out/config.gz" 2>"$out/config-error.txt"; then
  rm -f "$out/config.gz"
fi
if [ -f "$out/config.gz" ]; then
  gzip -t "$out/config.gz" 2>/dev/null && gzip -dc "$out/config.gz" >"$out/kernel.config" || rm -f "$out/config.gz"
fi
printf 'Audit saved in %s\nReview logs for identifiers before sharing.\n' "$out"
