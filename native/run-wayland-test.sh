#!/bin/sh
# RAM-only bounded compositor test; must be invoked explicitly on native Linux.
set -eu
[ "${1:-}" = --show-120-seconds ] || { echo 'Usage: run-wayland-test.sh --show-120-seconds' >&2; exit 2; }
export LD_LIBRARY_PATH=/gpu/lib
export LIBGL_DRIVERS_PATH=/gpu/lib/dri
export GBM_BACKENDS_PATH=/gpu/lib/gbm
export MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink
export VK_DRIVER_FILES=/gpu/turnip.json MESA_SHADER_CACHE_DISABLE=true
export P613_ZINK_KGSL_SDE=1
export LIBSEAT_BACKEND=builtin SEATD_VTBOUND=0
export XDG_RUNTIME_DIR=/run/wayland-test WAYLAND_DISPLAY=wayland-p613
# The vendor driver reserves the boot-splash plane on CRTC 100 until the first
# real modeset. Release it with the previously tested, bounded legacy KMS path.
# Do this once per native boot, before a compositor or client owns the display.
if [ ! -e /run/p613-splash-released ]; then
    /gpu/bin/display-test --show-120-seconds >/splash-handoff.log 2>&1 &
    handoff_pid=$!
    sleep 2
    kill -TERM "$handoff_pid" 2>/dev/null || true
    wait "$handoff_pid" || { echo 'Splash handoff failed'; exit 1; }
    touch /run/p613-splash-released
fi
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
: > /weston-test.log
: > /wayland-client.log
weston_pid= client_pid=
cleanup() {
    trap - EXIT INT TERM
    if [ -n "$client_pid" ]; then kill "$client_pid" 2>/dev/null || true; wait "$client_pid" 2>/dev/null || true; fi
    if [ -n "$weston_pid" ]; then kill "$weston_pid" 2>/dev/null || true; wait "$weston_pid" 2>/dev/null || true; fi
}
trap cleanup EXIT INT TERM
/gpu/bin/weston --backend=drm --renderer=gl --drm-device=card0 \
    --shell=kiosk-shell.so --config=/gpu/weston-test.ini --idle-time=0 \
    --continue-without-input --socket="$WAYLAND_DISPLAY" --log=/weston-test.log \
    >/weston-stdout.log 2>&1 &
weston_pid=$!
i=0
while [ ! -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; do
    kill -0 "$weston_pid" 2>/dev/null || { echo 'Weston exited before socket'; exit 1; }
    i=$((i+1)); [ "$i" -lt 20 ] || { echo 'Wayland socket timeout'; exit 1; }
    sleep 1
done
/gpu/bin/weston-simple-egl -f -o >/wayland-client.log 2>&1 &
client_pid=$!
echo "WAYLAND_TEST_ACTIVE weston_pid=$weston_pid client_pid=$client_pid duration=120s"
i=0
while [ "$i" -lt 120 ]; do
    kill -0 "$weston_pid" 2>/dev/null || { echo 'Weston exited during test'; exit 1; }
    kill -0 "$client_pid" 2>/dev/null || { echo 'Client exited during test'; exit 1; }
    sleep 1
    i=$((i+1))
done
echo 'WAYLAND_TEST_FINISHED'
