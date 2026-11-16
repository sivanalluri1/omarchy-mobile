#!/bin/sh
# Invoke from RAM init only, after mounting the verified read-only Arch root.
set -eu
case "${1:-}" in
--show-120-seconds) seconds=120;;
--show-extended-test)
  seconds=${P613_TEST_SECONDS:-600}
  case "$seconds" in ''|*[!0-9]*) exit 2;; esac
  [ "$seconds" -ge 300 ] && [ "$seconds" -le 3600 ] || exit 2
  ;;
*) echo 'Usage: run-arch-hyprland-test.sh --show-120-seconds|--show-extended-test' >&2; exit 2;;
esac
[ -f /run/arch-root-mounted ] || exit 1
[ -x /tmp/display-test ] || exit 1
qsg_loop=${P613_QSG_RENDER_LOOP:-basic}
case "$qsg_loop" in basic|threaded) ;; *) exit 2;; esac
if [ "${P613_ENABLE_INPUT:-0}" = 1 ]; then
  chroot /arch /usr/bin/python /usr/local/libexec/p613/setup-input.py >/input-setup.log 2>&1
fi
seat_pid=
cleanup() {
  trap - EXIT INT TERM
  # UID 1000 is reserved for this test; the recovery init/SSH processes are root.
  chroot /arch /usr/bin/pkill -TERM -u omarchy 2>/dev/null || true
  if [ -n "$seat_pid" ]; then kill -TERM "$seat_pid" 2>/dev/null || true; wait "$seat_pid" 2>/dev/null || true; fi
}
trap cleanup EXIT INT TERM
if [ ! -e /run/p613-splash-released ]; then
  /tmp/display-test --show-120-seconds >/splash-handoff.log 2>&1 &
  handoff=$!
  sleep 2
  kill -TERM "$handoff" 2>/dev/null || true
  wait "$handoff"
  touch /run/p613-splash-released
fi
render_gid=$(chroot /arch /usr/bin/getent group render | cut -d: -f3)
[ -n "$render_gid" ] || exit 1
for node in /dev/dri/card0 /dev/dri/renderD128 /dev/kgsl-3d0 /dev/ion; do
  [ -c "$node" ] || exit 1
  chown "0:$render_gid" "$node"
  chmod 660 "$node"
done
chroot /arch /usr/bin/env SEATD_VTBOUND=0 SEATD_SOCK=/run/seatd.sock \
  /usr/bin/seatd -g video -l info >/arch/run/seatd-test.log 2>&1 &
seat_pid=$!
i=0
while [ ! -S /arch/run/seatd.sock ]; do
  kill -0 "$seat_pid" || exit 1
  i=$((i+1)); [ "$i" -lt 20 ] || exit 1
  sleep 1
done
graphics_libraries=/opt/p613-gpu/lib
if [ "${P613_USE_UDEV_COMPAT:-0}" = 1 ]; then
  if [ -f /arch/opt/p613-compat/lib/libudev.so.1 ]; then
    graphics_libraries=/opt/p613-compat/lib:/opt/p613-gpu/lib
  else
    [ -f /arch/tmp/p613-compat/libudev.so.1 ] || exit 1
    graphics_libraries=/tmp/p613-compat:/opt/p613-gpu/lib
  fi
fi
root_label="read-only developer image"
if [ -f /run/arch-root-transport ]; then root_label=$(cat /run/arch-root-transport); fi
chroot /arch /usr/bin/runuser -u omarchy -- /usr/bin/env \
  P613_ROOT_LABEL="$root_label" P613_HYPRLAND_CONFIG="${P613_HYPRLAND_CONFIG:-/etc/p613/hyprland-test.lua}" \
  P613_TEST_SECONDS="$seconds" \
  P613_EXPECT_OMARCHY="${P613_EXPECT_OMARCHY:-0}" \
  P613_EXPECT_MOBILE="${P613_EXPECT_MOBILE:-0}" \
  P613_EXPECT_OSK="${P613_EXPECT_OSK:-0}" \
  QSG_RENDER_LOOP="$qsg_loop" \
  HOME=/home/omarchy USER=omarchy LOGNAME=omarchy TZ=America/Phoenix \
  XDG_RUNTIME_DIR=/run/user/1000 XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=Hyprland \
  INPUT_METHOD=none QT_IM_MODULE=wayland GTK_IM_MODULE=wayland XMODIFIERS=@im=none SDL_IM_MODULE=none \
  LD_LIBRARY_PATH="$graphics_libraries" GBM_BACKENDS_PATH=/opt/p613-gpu/lib/gbm \
  MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink P613_ZINK_KGSL_SDE=1 \
  VK_DRIVER_FILES=/opt/p613-gpu/share/vulkan/icd.d/freedreno_icd.aarch64.json \
  MESA_SHADER_CACHE_DISABLE=true AQ_DRM_DEVICES=/dev/dri/card0 \
  LIBSEAT_BACKEND=seatd SEATD_SOCK=/run/seatd.sock SEATD_VTBOUND=0 \
  /usr/bin/dbus-run-session -- /bin/bash /tmp/arch-hyprland-worker.sh
