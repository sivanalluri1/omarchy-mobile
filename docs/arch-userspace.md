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

- [x] Build a metadata-correct Arch root image and verify signed package installation.
- [x] Build and inspect the NBD-enabled kernel and a separately named BOOT candidate.
- [ ] Prove read-only SSD-root access and Arch commands on the actual 4.14 tablet.
- [ ] Reuse the patched KGSL/SDE Mesa stack with Arch's libraries (do not inject the old Debian libc/libstdc++ runtime).
- [ ] Prove Hyprland on the native panel, with a non-root desktop session.
- [ ] Integrate portable Omarchy/Omarchy Mobile packages and document unsupported services.
- [ ] Resolve the kernel/systemd support gap before calling this a complete supported Omarchy installation.

Completed sub-gates will be checked off only with build or device evidence.


## Offline userspace checkpoint

The NBD kernel built from unchanged sources and differs from the step 8 kernel configuration only by CONFIG_BLK_DEV_NBD=y. A separately named 96 MiB BOOT candidate preserves the installed DTB, header and AVB policy. SHA256: `71543681fdd66b0d5eab02065d5a61f10c808574ec6172991f6b0e3a9e5f0a70`. The original step 8 image is retained separately.

The signed Arch root upgrade, ext4 filesystem check and read-only NBD server test passed. Hyprland's minimal Lua profile passed its non-root `--verify-config` check in the build container. The custom Mesa prefix resolves libc/libstdc++ and other core dependencies from Arch. One leaf compatibility library, libdisplay-info.so.2 from the already-validated Debian graphics runtime, is required alongside Arch's .so.3; it is private to the Mesa prefix and recorded by hash. No older libc or C++ runtime is injected.

The desktop user has locked password authentication. PID 1/SSH remain in RAM; read-only NBD root, RAM session directories, a root seatd broker and a non-root D-Bus/Hyprland session form the hardware experiment. These are offline checks, not yet tablet proof at this checkpoint.


## Hardware test 05 checkpoint — transport failure

The new kernel booted, and its BOOT readback matched the candidate. The first read-only NBD connection and ext4 mount succeeded. On the tablet, Arch glibc 2.43, bash, pacman package queries and the UID 1000 desktop user worked. Systemd was queried as a package, not run as PID 1.

The first graphics probe stopped cleanly because the Vulkan loader package was missing. The image was unmounted/disconnected, its export stopped, and the signed Arch vulkan-icd-loader package was installed offline. On the subsequent connection/mount attempt in the same native boot, USB networking and SSH stopped responding. The second GPU probe had **not** started. The cause is not yet established; this is not evidence that the Arch GPU renderer failed. Physical Download Mode recovery and original-BOOT restoration are required before further hardware work.

Until diagnosed, the mount helper refuses a second NBD connection in the same boot. Exported image changes must be made between native boots. This is a containment measure, not a proven fix. The image is exported read-only and mounted ro,noload; Android filesystems were not mounted. The existing recovery init stays separate from Arch userspace, but a kernel-level stall can still take USB/SSH down, as observed here.

Test 05 recovery is complete: original BOOT and Android startup restored, all four original partition hashes matched, and the export stopped. Saved pstore is corrupted/incomplete and cannot establish the stall cause. Further graphics work will use a compressed RAM-backed root, avoiding NBD. The existing NBD helpers remain experimental and are not the next hardware path.
