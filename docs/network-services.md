# Native NetworkManager integration

Revision 9 packages signed Arch NetworkManager, wpa_supplicant and iw, plus the hash-checked private firmware and pinned radio support binaries. It replaces hardware test 10's temporary Debian connection tools. The firmware remains private; the repository contains source, hashes and build instructions.

The native BusyBox init remains PID 1. After staging the image, stage-packaged-radio.py copies its radio payload into the native RAM filesystem. The existing radio supervisor starts IPA, legacy QRTR discovery, protection-domain mapping, firmware transfer and the modem with read-only RMTFS shadow storage. Its firmware and helper files now come from the mounted image.

start-p613-network.sh starts a separate system D-Bus, D-Bus-enabled wpa_supplicant and NetworkManager inside Arch. NetworkManager uses the tested private libudev 257 compatibility library. It manages only wlan0; usb0 and Samsung's auxiliary interfaces remain unmanaged. The [NetworkManager device-selection configuration](https://networkmanager.dev/docs/api/latest/NetworkManager.conf.html) supports wildcard exclusions with an except interface specification.

NetworkManager state and saved connections live on tmpfs. A RAM-generated machine ID is bound over the image's machine-id file. The isolated single-user experiment bypasses polkit authorization because it has no logind session; this configuration is not a production multi-user policy. Systemd, hostname management and connectivity-check polling are not required for this test. USB recovery retains its original native addressing and DHCP service.

The upstream mobile quick-settings panel is enabled. Its first-Wi-Fi-device selection initially picked unmanaged swlan0. A P613-only patch chooses wlan0. The panel's native password sheet sends credentials locally through NetworkManager; neither the password nor the saved keyfile is transferred to the host or committed. The saved profile is lost at power-off. During final-image validation a profile was retained only in the tablet's native RAM across the Arch-root restart.

/etc/resolv.conf is a symlink to /run/NetworkManager/resolv.conf. This follows atomic resolver-file replacement after lease changes; a one-off file bind would retain an old inode. Connection profiles use a tmpfs mounted over /etc/NetworkManager/system-connections, so normal NetworkManager profile creation works with a read-only SquashFS root.

stop-p613-network.sh stops NetworkManager, the supplicant and the system bus, then removes the network-specific mounts. Stop these before stopping the radio supervisor or unmounting Arch. Audio/UPower and general service supervision remain separate milestones.
