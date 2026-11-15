# First native Linux boot — SM-P613

Tested on November 14, 2026 (America/Phoenix). The authorized BOOT-only experiment succeeded and the original Android BOOT image was restored afterward.

## Verified on the tablet

| Check | Result |
| --- | --- |
| Native kernel | 4.14.357, omarchy@p613-builder, Debian LLVM 19.1.7 |
| Running BOOT image | SHA256 exactly matched the validated candidate |
| PID 1 | /bin/sh /init from the RAM-only archive |
| Filesystems | Only rootfs and virtual/RAM filesystems mounted; no Android filesystems |
| USB networking | NCM enumerated as Mac en5; DHCP OFFER/ACK assigned 192.168.77.2 |
| SSH | Dedicated public-key authentication and pinned host-key verification succeeded |
| Protected images | Recovery, DTBO and vbmeta hashes unchanged while native Linux ran |
| Return to Download Mode | Static ARM64 helper used the kernel restart2("download") interface over SSH |
| Android restoration | Original BOOT restored; LineageOS boot completion and USB ADB verified |
| Final image integrity | BOOT, recovery, DTBO and vbmeta all exactly matched preflight hashes |

Candidate SHA256: `9b6355d7a4380b418d7491219c19dc54051a008e6ab1544fe3df5431d6a93be5`.
Restored BOOT SHA256: `15966f29996c7ab4c299d7b95f7a1e3ae04ef9ea788e4d11fc66f96eec2753ed`.

The reboot helper was compiled locally as a static AArch64 executable, uploaded only to the native RAM filesystem and verified by SHA256 before execution. It did not remain installed in Android. The write commands used explicit BOOT mapping only; no erase/PIT/CSC/bulk firmware operation was used. No manual Mac network configuration was needed.

## Observed, not yet functionally validated

DRM card0/renderD128 and KGSL nodes were present; the DSI connector reported connected. sec_touchscreen and sec_e-pen input devices were registered. These observations do not establish visible rendering, acceleration, touch/pen behavior or a working desktop.

The native clock was not initialized to normal wall time, so raw device timestamps are unreliable. udhcpd's first-start missing lease-file warning did not prevent DHCP. SDE probe messages included a flash-gamma property parse warning and invalid feature-map warnings; their impact is unknown.

## Next milestone

Investigate the downstream DRM/SDE and KGSL userspace interfaces. Begin with resource/connector/plane capability enumeration, then a controlled display test; prove GPU rendering separately before Hyprland integration. Kernel 4.14 compatibility with a full Arch/systemd userspace remains an independent requirement.

Raw logs remain private under ignored SSD work/hardware-test-01. The sanitized [machine-readable result](build-records/hardware-test-01.json) records the evidence. No further hardware write is implied by this report.
