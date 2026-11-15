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
  echo OMARCHY_SHELL_ACTIVE
fi
echo "ARCH_HYPRLAND_ACTIVE pid=$compositor duration=${seconds}s"
for ((i=0;i<seconds;i++)); do
  kill -0 "$compositor" 2>/dev/null || { echo 'Hyprland exited during test'; exit 1; }
  if [[ ${P613_EXPECT_OMARCHY:-0} == 1 ]] && ((i % 15 == 0)); then
    [[ $(omarchy-shell shell ping) == ok ]] || exit 1
    omarchy-shell shell listPlugins | jq -e 'any(.[]; .id == "omamobile.bar" and .active == true)' >/dev/null
  fi
  sleep 1
done
echo 'ARCH_HYPRLAND_FINISHED'
