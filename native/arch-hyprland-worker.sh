#!/bin/bash
# Run as the unprivileged desktop user inside Arch, under dbus-run-session.
set -eu
config=${P613_HYPRLAND_CONFIG:-/etc/p613/hyprland-test.lua}
seconds=${P613_TEST_SECONDS:-120}
[[ $seconds =~ ^[0-9]+$ ]] && ((seconds>=120 && seconds<=3600)) || exit 2
Hyprland --config "$config" >/tmp/hyprland-test.log 2>&1 &
compositor=$!
cleanup() {
  trap - EXIT INT TERM
  kill -TERM "$compositor" 2>/dev/null || true
  wait "$compositor" 2>/dev/null || true
}
trap cleanup EXIT INT TERM
check_shell() {
  local attempt
  for attempt in 1 2 3; do
    if [[ $(OMARCHY_SHELL_IPC_TIMEOUT=3s omarchy-shell shell ping 2>/dev/null || true) == ok ]]; then
      return 0
    fi
    echo "OMARCHY_IPC_RETRY attempt=$attempt" >&2
    sleep 1
  done
  return 1
}
check_mobile() {
  omarchy-shell shell call omamobile.home state '' | jq -e '.loaded == true and .pages > 0' >/dev/null || return 1
  omarchy-shell shell call omamobile.launcher state '' | jq -e '.apps > 0 and .library != "none"' >/dev/null
}
check_osk() {
  gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 \
    --method org.freedesktop.DBus.Properties.Get sm.puri.OSK0 Visible >/dev/null || return 1
  omarchy-shell shell call omamobile.keyboard state '' | jq -e '.watcher == true' >/dev/null
}
for ((i=0;i<60;i++)); do
  kill -0 "$compositor" 2>/dev/null || { echo 'Hyprland exited during startup'; exit 1; }
  if find "$XDG_RUNTIME_DIR" -maxdepth 1 -type s -name 'wayland-*' | grep -q .; then break; fi
  sleep 1
done
find "$XDG_RUNTIME_DIR" -maxdepth 1 -type s -name 'wayland-*' | grep -q . || { echo 'Wayland socket timeout'; exit 1; }
if [[ ${P613_EXPECT_OMARCHY:-0} == 1 ]]; then
  export OMARCHY_PATH=/usr/share/omarchy
  display_socket=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -type s -name 'wayland-*' | head -1)
  export WAYLAND_DISPLAY=${display_socket##*/}
  shell_ready=0
  for ((i=0;i<20;i++)); do
    if [[ $(omarchy-shell shell ping 2>/dev/null || true) == ok ]] &&
       omarchy-shell shell listPlugins | jq -e 'any(.[]; .id == "omamobile.bar" and .active == true)' >/dev/null; then
      shell_ready=1
      break
    fi
    sleep 1
  done
  ((shell_ready==1)) || { echo 'Omarchy shell/bar startup failed'; exit 1; }
  if [[ ${P613_EXPECT_MOBILE:-0} == 1 ]]; then
    mobile_ready=0
    for ((i=0;i<20;i++)); do
      if check_mobile 2>/dev/null; then mobile_ready=1; break; fi
      sleep 1
    done
    ((mobile_ready==1)) || { echo 'Mobile home/launcher startup failed'; exit 1; }
    echo OMARCHY_MOBILE_READY
  fi
  echo OMARCHY_SHELL_ACTIVE
  if [[ ${P613_EXPECT_OSK:-0} == 1 ]]; then
    osk_ready=0
    for ((i=0;i<20;i++)); do
      if check_osk 2>/dev/null; then osk_ready=1; break; fi
      sleep 1
    done
    ((osk_ready==1)) || { echo 'On-screen keyboard startup failed'; exit 1; }
    echo OMARCHY_OSK_READY
  fi
fi
echo "ARCH_HYPRLAND_ACTIVE pid=$compositor duration=${seconds}s"
for ((i=0;i<seconds;i++)); do
  kill -0 "$compositor" 2>/dev/null || { echo 'Hyprland exited during test'; exit 1; }
  if [[ ${P613_EXPECT_OMARCHY:-0} == 1 ]] && ((i % 15 == 0)); then
    check_shell || exit 1
    omarchy-shell shell listPlugins | jq -e 'any(.[]; .id == "omamobile.bar" and .active == true)' >/dev/null
    if [[ ${P613_EXPECT_MOBILE:-0} == 1 ]]; then check_mobile; fi
    if [[ ${P613_EXPECT_OSK:-0} == 1 ]]; then check_osk; fi
  fi
  sleep 1
done
echo 'ARCH_HYPRLAND_FINISHED'
