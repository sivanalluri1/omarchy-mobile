#!/bin/bash
# Run as the unprivileged desktop user inside Arch, under dbus-run-session.
set -eu
Hyprland --config /etc/p613/hyprland-test.lua >/tmp/hyprland-test.log 2>&1 &
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
echo "ARCH_HYPRLAND_ACTIVE pid=$compositor duration=120s"
for ((i=0;i<120;i++)); do
  kill -0 "$compositor" 2>/dev/null || { echo 'Hyprland exited during test'; exit 1; }
  sleep 1
done
echo 'ARCH_HYPRLAND_FINISHED'
