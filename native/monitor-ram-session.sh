#!/bin/sh
# Bounded, read-only RAM/GPU memory samples from the recovery init environment.
set -eu
duration=${1:-120}
case "$duration" in ''|*[!0-9]*) exit 2;; esac
[ "$duration" -ge 30 ] && [ "$duration" -le 3600 ] || exit 2
elapsed=0
while [ "$elapsed" -le "$duration" ]; do
  echo "MEMORY_SAMPLE elapsed=$elapsed"
  grep -E '^(MemAvailable|MemFree|AnonPages|Shmem|Slab|CmaFree):' /proc/meminfo
  for path in /sys/kernel/ion/total_heaps_kb /sys/kernel/ion/total_pools_kb /sys/class/kgsl/kgsl/page_alloc /sys/class/kgsl/kgsl/mapped; do
    if [ -r "$path" ]; then
      read -r value < "$path"
      echo "$path $value"
    fi
  done
  sleep 5
  elapsed=$((elapsed+5))
done
