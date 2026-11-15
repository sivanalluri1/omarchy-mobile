#!/usr/bin/env bash
# Executed inside the new, SSD-backed Arch chroot, never on Android or macOS.
set -euo pipefail
pacman-key --init
pacman-key --populate archlinuxarm archlinux
pacman -Sy --noconfirm --needed archlinuxarm-keyring archlinux-keyring
# Remove the generic kernel; the Samsung BOOT image remains the only tablet kernel.
if pacman -Q linux-aarch64 >/dev/null 2>&1; then
  pacman -Rdd --noconfirm linux-aarch64
fi
pacman -Syu --noconfirm --needed hyprland dbus seatd foot wayland-utils procps-ng
if ! id omarchy >/dev/null 2>&1; then
  if id alarm >/dev/null 2>&1 && [ "$(id -u alarm)" = 1000 ]; then
    usermod -l omarchy -d /home/omarchy -m alarm
    groupmod -n omarchy alarm
  else
    useradd -m -u 1000 -s /bin/bash omarchy
  fi
fi
for group in video render input; do groupadd -f "$group"; done
usermod -aG video,render,input omarchy
passwd -l root
passwd -l alarm 2>/dev/null || true
passwd -l omarchy
pacman -Q > /root/p613-package-manifest.txt
printf 'Arch native userspace experiment; BusyBox remains PID 1.\n' > /etc/p613-bringup
