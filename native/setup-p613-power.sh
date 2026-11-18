#!/bin/sh
# Run from native init, not inside Arch. Expose only root-owned PM attributes.
set -eu
[ "$(uname -r)" = 4.14.357-openela-perf-g21b136df1533 ] || exit 2
[ -f /run/arch-root-mounted ] || exit 2
mounted() { awk -v target="$1" '$2 == target { found=1 } END { exit !found }' /proc/mounts; }
case "${1:-}" in
enable)
    newly_mounted=''
    cleanup_failed() {
        for name in $newly_mounted; do umount "/arch/sys/power/$name" || true; done
    }
    trap cleanup_failed EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    for name in pm_async wakeup_count state; do
        target=/arch/sys/power/$name
        [ -f "$target" ] && [ -f "/sys/power/$name" ] || exit 1
        if ! mounted "$target"; then
            mount --bind "/sys/power/$name" "$target"
            newly_mounted="$name $newly_mounted"
        fi
    done
    touch /run/p613-power-bindings
    trap - EXIT INT TERM
    echo P613_POWER_ATTRIBUTES_READY
    ;;
disable)
    for name in state wakeup_count pm_async; do
        target=/arch/sys/power/$name
        if mounted "$target"; then umount "$target"; fi
    done
    rm -f /run/p613-power-bindings
    echo P613_POWER_ATTRIBUTES_REMOVED
    ;;
*) echo 'usage: setup-p613-power.sh enable|disable' >&2; exit 2;;
esac
