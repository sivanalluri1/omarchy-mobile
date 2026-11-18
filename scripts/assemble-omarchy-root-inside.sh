#!/usr/bin/env bash
set -euo pipefail
mknod /dev/loop-control c 10 237
for n in $(seq 0 63); do mknod "/dev/loop$n" b 7 "$n"; done
loop=$(losetup --find --show /out/root.img)
mkdir -p /target
cleanup() {
  if mountpoint -q /target; then
    if [ -c /target/dev/null ]; then chroot /target /usr/bin/gpgconf --homedir /etc/pacman.d/gnupg --kill all || true; fi
    umount -R /target
  fi
  losetup -d "$loop"
}
trap cleanup EXIT
mount "$loop" /target
mount --rbind /dev /target/dev
mount --make-rslave /target/dev
mount -t proc proc /target/proc
cp --remove-destination /etc/resolv.conf /target/etc/resolv.conf
python3 /project/scripts/stage-omarchy-payload.py
# Verify signatures against the explicitly pinned TLS-bootstrapped Omarchy keyring.
mkdir -m700 /tmp/omarchy-gnupg
gpg --batch --homedir /tmp/omarchy-gnupg --import /tmp/usr/share/pacman/keyrings/omarchy.gpg
gpg --batch --homedir /tmp/omarchy-gnupg --with-colons --fingerprint | grep -F "fpr:::::::::40DFB630FF42BCFFB047046CF0134EE680CAC571:"
gpg --batch --homedir /tmp/omarchy-gnupg --verify /inputs/omarchy.pkg.tar.zst.sig /inputs/omarchy.pkg.tar.zst
gpg --batch --homedir /tmp/omarchy-gnupg --verify /inputs/quickshell.pkg.tar.zst.sig /inputs/quickshell.pkg.tar.zst
gpg --batch --homedir /tmp/omarchy-gnupg --verify /inputs/settings.pkg.tar.zst.sig /inputs/settings.pkg.tar.zst
chroot /target /bin/bash -s <<'ARCH'
set -euo pipefail
packages=(qt6-base qt6-declarative qt6-svg qt6-wayland cpptrace jemalloc libpipewire polkit hicolor-icon-theme jq python python-dbus python-gobject inotify-tools socat grim ttf-jetbrains-mono-nerd squeekboard gsettings-desktop-schemas dconf wtype libbsd networkmanager wpa_supplicant iw alsa-utils pipewire pipewire-audio wireplumber pipewire-pulse)
if [ "${P613_REUSE_PACKAGES:-0}" = 1 ]; then
  pacman -Q "${packages[@]}" >/dev/null
else
  pacman -Syu --noconfirm --needed "${packages[@]}"
fi
usermod -aG audio omarchy
find /var/cache/pacman/pkg -mindepth 1 -maxdepth 1 -type f -delete
pacman -Q > /root/p613-package-manifest.txt
ARCH
# Runtime-only payloads, not a dependency-bypassed installation of the full desktop.
bsdtar -xf /inputs/quickshell.pkg.tar.zst -C /target --exclude='.PKGINFO' --exclude='.BUILDINFO' --exclude='.MTREE' --exclude='.INSTALL'
install -Dm755 /project/native/p613-omarchy-session /target/usr/local/bin/p613-omarchy-session
install -Dm755 /project/native/p613-launch-desktop /target/usr/local/bin/p613-launch-desktop
install -Dm755 /project/native/p613-osk-test.py /target/usr/local/bin/p613-osk-test
install -Dm644 /project/configs/p613-osk-test.desktop /target/usr/share/applications/p613-osk-test.desktop
install -Dm755 /project/native/setup-p613-input.py /target/usr/local/libexec/p613/setup-input.py
install -Dm644 /project/configs/p613-NetworkManager.conf /target/etc/p613/NetworkManager.conf
install -Dm755 /project/native/start-p613-network.sh /target/usr/local/libexec/p613/start-network.sh
install -Dm755 /project/native/stop-p613-network.sh /target/usr/local/libexec/p613/stop-network.sh
install -Dm755 /project/native/p613-audio-route.py /target/usr/local/libexec/p613/audio-route.py
install -Dm755 /project/native/p613-power-status.py /target/usr/local/libexec/p613/power-status.py
python3 - <<'POWERPROBE'
import hashlib,json
from pathlib import Path
record=json.loads(Path('/project/docs/build-records/power-probe-build.json').read_text())
assert hashlib.sha256(Path('/project/native/p613-suspend-test.c').read_bytes()).hexdigest()==record['source_sha256']
assert hashlib.sha256(Path('/power-probe').read_bytes()).hexdigest()==record['binary_sha256']
POWERPROBE
install -Dm750 /power-probe /target/usr/local/libexec/p613/suspend-probe
install -Dm750 /project/native/p613-power-button.py /target/usr/local/libexec/p613/power-button.py
install -Dm755 /project/native/p613-speaker-test.py /target/usr/local/libexec/p613/speaker-test.py
install -Dm755 /project/native/p613-microphone-test.py /target/usr/local/libexec/p613/microphone-test.py
install -Dm644 /project/configs/p613-pipewire-speakers.conf /target/etc/pipewire/pipewire.conf.d/90-p613-speakers.conf
install -Dm644 /project/configs/p613-wireplumber.conf /target/etc/wireplumber/wireplumber.conf.d/90-p613-native.conf
python3 /project/scripts/package-radio-payload.py
install -Dm644 /project/configs/hyprland-p613-omarchy.lua /target/etc/p613/hyprland-omarchy.lua
install -Dm644 /project/configs/omarchy-p613-shell.json /target/etc/p613/shell.json
chroot /target /usr/bin/qs --version
chroot /target /usr/bin/env LD_LIBRARY_PATH=/opt/p613-compat/lib /usr/bin/ldd /usr/bin/quickshell > /out/quickshell-ldd.txt
! grep -q 'not found' /out/quickshell-ldd.txt
chroot /target /usr/bin/env LD_LIBRARY_PATH=/opt/p613-compat/lib:/opt/p613-gpu/lib /usr/bin/ldd /usr/bin/squeekboard > /out/squeekboard-ldd.txt
! grep -q 'not found' /out/squeekboard-ldd.txt
chroot /target /usr/bin/python -c "import gi; gi.require_version('Gtk','3.0'); from gi.repository import Gtk; print('GTK_INPUT_FIXTURE_IMPORT_PASS')"
chroot /target /usr/bin/NetworkManager --version
chroot /target /usr/bin/nmcli --version
chroot /target /usr/bin/wpa_supplicant -v
chroot /target /usr/bin/pipewire --version
chroot /target /usr/bin/wireplumber --version
chroot /target /usr/bin/aplay --version
chroot /target /usr/bin/env LD_LIBRARY_PATH=/opt/p613-compat/lib /usr/bin/ldd /usr/bin/NetworkManager > /out/networkmanager-ldd.txt
! grep -q 'not found' /out/networkmanager-ldd.txt
mkdir -p /target/tmp/p613-runtime
chown 1000:1000 /target/tmp/p613-runtime
chmod 700 /target/tmp/p613-runtime
chroot /target /usr/bin/runuser -u omarchy -- /usr/bin/env XDG_RUNTIME_DIR=/tmp/p613-runtime /usr/bin/Hyprland --verify-config --config /etc/p613/hyprland-omarchy.lua
chroot /target /usr/bin/pacman -Q > /out/package-versions.txt
chroot /target /usr/bin/gpgconf --homedir /etc/pacman.d/gnupg --kill all || true
umount /target/proc
umount -R /target/dev
sync
mksquashfs /target /out/root.squashfs -noappend -comp xz -b 1048576 -processors 4 -no-progress -wildcards -e 'dev/*' 'proc/*' 'sys/*' 'run/*' 'tmp/*'
python3 - <<'PY'
import hashlib,json
from pathlib import Path
p=Path('/out/root.squashfs')
assert p.stat().st_size < 768*1024*1024
record={'bytes':p.stat().st_size,'sha256':hashlib.file_digest(p.open('rb'),'sha256').hexdigest(),'tablet_tested':False,'systemd_pid1':False}
Path('/out/validation.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record))
PY
