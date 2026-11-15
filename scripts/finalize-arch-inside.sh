#!/usr/bin/env bash
set -euo pipefail
pacman -S --noconfirm --needed ttf-dejavu
# Needed by libdbus clients; unique to this private experiment image.
if [ ! -s /etc/machine-id ]; then dbus-uuidgen > /etc/machine-id; fi
dbus-uuidgen --ensure=/etc/machine-id
pacman -Q > /root/p613-package-manifest.txt
