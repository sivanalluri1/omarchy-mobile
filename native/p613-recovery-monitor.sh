#!/bin/sh
# Read-only, bounded USB recovery diagnostics. Redirect to a private RAM log.
set -eu
[ "$(uname -r)" = 4.14.357-openela-perf-g21b136df1533 ] || exit 2
for sample in $(seq 1 360); do
    echo "RECOVERY_SAMPLE $sample"
    cat /proc/uptime
    ip -4 addr show usb0 2>&1 || true
    for f in /sys/class/net/usb0/operstate /sys/class/net/usb0/carrier \
      /sys/class/net/usb0/statistics/rx_packets /sys/class/net/usb0/statistics/tx_packets \
      /sys/class/net/usb0/statistics/rx_errors /sys/class/net/usb0/statistics/tx_errors \
      /sys/bus/platform/devices/a600000.ssusb/power/runtime_status; do
        if [ -r "$f" ]; then echo "$f"; cat "$f" || true; fi
    done
    grep -Ei 'dwc3|ssusb|xhci' /proc/interrupts || true
    sleep 10
done
