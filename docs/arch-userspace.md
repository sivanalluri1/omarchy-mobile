# Step 9 — Arch Linux ARM userspace

Status: in progress. Step 8's native GPU/Wayland proof remains intact; a full Arch/systemd/Omarchy boot is not yet established.

## Compatibility findings

The inspected Arch Linux ARM repositories offer glibc 2.43, systemd 262.2, Hyprland 0.57.2 and Aquamarine 0.16.0. The glibc AArch64 binary declares Linux 3.7.0 as its minimum; this permits testing on 4.14 but does not establish that every package works. Systemd 262.2's own README declares Linux 5.10 as the unsupported-below minimum. Therefore the running 4.14 kernel cannot be treated as a supported current systemd platform. The existing BusyBox PID 1 and pinned-key SSH stay in control during the userspace experiment.

Sources: [systemd v262.2 requirements](https://github.com/systemd/systemd/blob/v262.2/README), [Arch Linux ARM generic userspace](https://archlinuxarm.org/platforms/armv8/generic).

Omarchy Mobile snapshot `1da3f04b1c9bb70d97ba4ce6a2510bf92d79bfe5` targets a mainline-kernel, systemd-based installation. Its Pixel installer and device packages cannot be used as the Samsung storage/boot integration. Selected portable desktop components must be integrated separately. A manually launched Arch session is a userspace compatibility test; it does not demonstrate a supported systemd boot or the complete Omarchy shell.

## Root filesystem transport

Use an ext4 filesystem image stored on the user's SSD and exported **read-only over the private USB network** via NBD. The native kernel adds CONFIG_BLK_DEV_NBD=y; all other minimal-kernel options stay unchanged. BusyBox's existing nbd-client connects to the host at 192.168.77.2. The tablet mounts only /dev/nbd0, read-only with journal replay disabled. Android partitions remain unmounted. The BOOT-only experiment/restore workflow remains the same.

The full userspace is too large for the initial RAM root. Its /run, /tmp and desktop home will use RAM mounts for writable session state. A failed userspace session does not replace PID 1 or its USB/SSH recovery connection. The SSD image contains a developer userspace, not tablet userdata.

Build the filesystem inside a Linux loop-mounted ext4 **file**. Direct extraction onto the macOS APFS bind mount failed to preserve root ownership/read-only-directory semantics. The failed staging tree is retained privately; it is not used as a bootable root. Linux ext4 loop-mount ownership/mode behavior was verified before continuing. New filesystems disable orphan_file and metadata_csum_seed for compatibility with the 4.14 ext4 driver. Libarchive's bsdtar preserves the archive's extended metadata.

## Inputs and package trust

The generic AArch64 archive was obtained using valid HTTPS from the fixed Arch Linux ARM mirror `fl.us.mirror.archlinuxarm.org`. The geolocation hosts had certificate-name failures, also observed in Chrome; certificate verification was not disabled. Archive SHA256: `42a4eeaa038994ffd31fa173256ef2f0ef511358eeb41b9ea1f8626391b9b319`. Package installation keeps pacman's required signature checks and the distribution's keyrings. This archive is a TLS/checksum-pinned bootstrap; no detached archive signature has been verified.

## Next gates

- [ ] Build a metadata-correct Arch root image and verify signed package installation.
- [ ] Build and inspect the NBD-enabled kernel and a separately named BOOT candidate.
- [ ] Prove read-only SSD-root access and Arch commands on the actual 4.14 tablet.
- [ ] Reuse the patched KGSL/SDE Mesa stack with Arch's libraries (do not inject the old Debian libc/libstdc++ runtime).
- [ ] Prove Hyprland on the native panel, with a non-root desktop session.
- [ ] Integrate portable Omarchy/Omarchy Mobile packages and document unsupported services.
- [ ] Resolve the kernel/systemd support gap before calling this a complete supported Omarchy installation.

Completed sub-gates will be checked off only with build or device evidence.
