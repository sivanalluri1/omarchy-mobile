# Progress

Status: step 9 in progress. First native Arch read-only SSD-root connection and commands passed. A subsequent NBD connection/mount attempt lost USB/SSH responsiveness; Android is restored and all four original hashes verified. Step 8 graphics proof remains valid.

- [x] Read-only SM-P613 hardware audit.
- [x] Pin and fetch the exact running kernel source.
- [x] Review Samsung restrictions and ROM installation/upgrade history.
- [x] Inspect matching recovery/vbmeta release archive offline.
- [x] Create plan, architecture and development steps.
- [x] 1. Validate local ARM64 Linux kernel builder.
- [x] 2. Generate and compare unchanged vendor configuration.
- [x] 3. Compile and inspect unchanged kernel/device-tree outputs.
- [x] 4. Verify installed recovery, Download Mode status and restoration set.
- [x] 5. Build minimal Linux configuration/initramfs with NCM and SSH.
- [x] 6. Validate candidate image packaging and review BOOT-only rollback.
- [x] 7. Prove native boot and USB/SSH on hardware; restore Android afterward.
- [x] 8. Prove display and accelerated Wayland.
- [ ] 9. Integrate Arch Linux ARM and Omarchy.
- [ ] 10. Validate remaining tablet hardware.

## Current work

Step 1 passed: ARM64 Debian container built; clang/LLD 19.1.7, native executable and AArch64 object compilation verified. Evidence: docs/build-records/builder-validation.txt.

Step 2 passed: generated vendor configuration has zero symbol-value differences against the running tablet config. Evidence: docs/build-records/vendor-config-comparison.json.

The macOS checkout has case-colliding filenames. A fresh checkout from its Git objects is clean in Docker Linux storage; builds use that read-only source and case-sensitive output volumes. Earlier source-cleanliness claims applied insufficient validation and are superseded by this Linux checkout check.

Step 3 passed: unchanged source compiled with LLVM 19.1.7 and external DTC 1.7.2. Image header, AArch64 ELF, both device-tree blobs and source cleanliness verified. The 52,684,824-byte Image and artifact hashes are recorded in docs/build-records/kernel-baseline-artifacts.json.

Step 4 in progress: matching LineageOS ROM ZIP and recovery TAR downloaded and digest-verified. Boot/DTBO/recovery inventory recorded. User reports internal storage is backed up. Physical USB ADB verified. Exact installed boot/recovery/DTBO/vbmeta backed up and device hashes verified using existing Magisk root. Installed recovery identifies 23.2-20260820. Rebooted to Download Mode for transport checks; initial USB enumeration was delayed, then detection and a 90-entry PIT read succeeded. Physical exit and Android/ADB return verified. Named screen fields were not visible. Matching factory firmware downloaded; archive SHA256 recorded and all ZIP members passed CRC checks. Nested TAR.MD5 validation and final restoration review remain pending. See docs/recovery-preparation.md. No flashing has been performed; one deliberate Download Mode reboot was issued.

## Build compatibility notes

- Native ARM64 LLVM 19 differs from the installed ROM's Android LLVM 21; no byte-identical reproduction is claimed.
- The bundled DTC failed parsing the Samsung overlay. Using the supported DTC_EXT=/usr/bin/dtc override succeeded without source edits.
- CONFIG_BPFILTER is disabled in the baseline; the build's bpfilter linker-probe warning did not omit an enabled feature.
- About 40 GiB internal space remained after compilation and downloading the restoration ROM. External SSD is not yet required; request it before larger parallel baselines or approaching the 20 GiB threshold.

### Step 4 checklist

- [x] Physical USB ADB verified.
- [x] User confirms internal storage backup.
- [x] Exact installed boot/recovery/DTBO/vbmeta captured and hash-verified.
- [x] Installed recovery release and vbmeta flags inspected.
- [x] Available Download Mode observations recorded; named OEM/KG/FRP/SWREV fields not exposed.
- [x] Working Download Mode USB session and PIT read verified.
- [x] Return to Android verified.
- [x] Restoration inputs and BOOT-only rollback mapping reviewed; factory archive and all four nested TAR.MD5 payloads verified. Actual restore writes remain untested.

## Previous pause checkpoint (resumed)

Tablet returned to Android; USB ADB verified, sys.boot_completed=1 and flash.locked=0. No flashing or erase performed. Exact boot-chain backups, matching LineageOS release and factory firmware archive are local under ignored work/. Installed boot kernel/DTB match the ROM ZIP; ramdisk differs. Step 4 remains open for nested factory-package validation and final restoration review. Resume after the user attaches the SSD and supplies its volume name. No build/download process remains running.

## Resumed on SSD

SSD storage configured under /Volumes/siva_ssd/Development/Omarchy. A case-sensitive APFS sparsebundle mounts at /Volumes/OmarchyBuild. Source cleanliness and baseline hashes match after migration; work/ is now an SSD symlink after checksum comparison. Original internal work copy and Docker volumes remain intact as fallbacks.

Step 4 complete for offline development readiness: exact installed images, recovery identity, Download Mode PIT/read-only transport and return to Android verified; matching factory ZIP and four nested TAR.MD5 payloads checked. Named OEM/KG/FRP/SWREV text was not exposed and a restore write has not been tested. Those limits remain part of the later hardware test review.

Step 5 in progress: minimal Linux kernel configuration and a RAM-only USB NCM / key-only SSH initramfs. No flashing or device reboot in this resumed session.

## Step 5 completed

Minimal kernel compiled successfully from clean pinned sources on SSD; Image/ELF/device-tree/config hashes inspected. Only DEVTMPFS, DEVTMPFS_MOUNT and FHANDLE differ from the running vendor config. RAM-only initramfs built; native ARM64 BusyBox, chroot shell and real key-only SSH remote command passed in an isolated container. Archive ownership/modes/device nodes inspected and client private key excluded. USB NCM/DHCP and tablet boot remain untested. Source: docs/minimal-linux.md; evidence: docs/build-records/kernel-minimal-artifacts.json and initramfs-validation.json.

Next: step 6, inspect the BOOT-only candidate and review its exact hardware-test/rollback scope. No image has been flashed.

## Step 6 completed — hardware gate

BOOT-only candidate generated at 96 MiB and inspected. AOSP tools verified its AVB footer/hash; embedded kernel, initramfs and installed DTB match validated inputs. Load addresses, OS compatibility fields and command line are preserved. Current unsigned algorithm NONE / flags 3 retained. Exact candidate/rollback hashes and proposed commands are in docs/boot-experiment.md. No flash or native boot has occurred. Step 7 requires explicit authorization for the first BOOT-only test and restoration of Android afterward.

## Step 7 completed — real hardware

User authorized the first BOOT-only test and restoration. Candidate flashed and booted native Linux; on-device BOOT hash matched the candidate. USB NCM, DHCP and pinned-key SSH worked. PID 1 was the RAM-only /init and no Android filesystem was mounted. Recovery/DTBO/vbmeta remained unchanged. Re-entered Download Mode over native SSH, restored the exact original BOOT, and verified Android boot completion, USB ADB and all four original partition hashes. See docs/hardware-test-01.md and docs/build-records/hardware-test-01.json.

Step 8 remains incomplete: DRM/KGSL nodes and a connected DSI connector were observed, but no visible display or GPU acceleration test has run. Tablet is currently back in its original rooted LineageOS installation. No further flash is running.


## Step 8 — display milestone

- [x] Build static ARM64 DRM/KGSL enumeration and bounded display tools.
- [x] Query real display modes and Adreno device information under native Linux.
- [x] Display CPU-rendered colour bars at 1200 × 2000, 60 Hz; user confirmed visible output.
- [x] Prove GPU rendering through Turnip/KGSL without software fallback.
- [x] Prove GPU/display buffer sharing and accelerated Wayland.

The known-good BOOT candidate was reused. Firmware was copied from Android into the native RAM rootfs; no Android filesystem was mounted. DSI modesetting succeeded; KGSL device query succeeded. Evidence and source/build commands: docs/graphics-bringup.md and docs/build-records/hardware-test-02.json. Full step 8 is not yet complete.

After test 02, the exact original BOOT was restored. Android boot completion and unlocked state were verified; BOOT/recovery/DTBO/vbmeta all match their preflight hashes. No hardware test remains running.

### Step 8 — Turnip build

- [x] Build pinned Mesa Turnip with the KGSL backend for AArch64.
- [x] Build bounded GPU compute dispatch/readback probe and Turnip-only runtime.
- [x] Verify no-device container test fails instead of selecting a software driver.

Hardware shader execution remains pending at this checkpoint. See docs/build-records/turnip-build.json.


### Step 8 — hardware compute passed

- [x] Run a real Vulkan compute shader on Adreno 618 through Turnip/KGSL.
- [x] Verify all 1,024 GPU-produced values and zero exit status, with Turnip as the only ICD.
- [x] Restore original Android BOOT and verify boot completion and all four original partition hashes after test 03.

Hardware reports Turnip Adreno (TM) 618, Vulkan 1.3.354. This proves GPU shader execution, but graphics rasterization, GPU/display buffer sharing and accelerated Wayland remain open. Next: Zink/EGL rendering. Evidence: docs/build-records/hardware-test-03.json.


## Step 8 completed — accelerated Wayland on hardware

- [x] Render and verify every pixel of a GPU triangle through Zink/Turnip (1,152 red + 2,944 blue).
- [x] Diagnose and patch repeated downstream DRM plane formats in Weston.
- [x] Add an opt-in, hardware-restricted Zink bridge for separate KGSL/SDE identities.
- [x] Verify GBM DMA-BUF export, valid scanout handles, EGL swap and front-buffer lock.
- [x] Release Samsung's initial splash-plane reservation using the validated legacy modeset path.
- [x] Run Weston GL on DSI-1 at 1200 × 2000 / 60 Hz with a Wayland EGL client.
- [x] User confirms rotation, then continuous rotation during the automated repeat.
- [x] Complete both bounded two-minute sessions with zero exit status, including automated splash handoff.
- [x] Verify all 405 final runtime files by hash on the native tablet.

Evidence: docs/graphics-bringup.md, docs/build-records/wayland-build.json and hardware-test-04.json. No Android filesystem was mounted. Initial repaint-clock warnings and a pending-flip shutdown message remain documented; no performance or long-duration stability claim is made. Input remains unconfigured in this minimal runtime. Hyprland/Arch/Omarchy have not run; step 9 must begin by checking userspace compatibility with kernel 4.14.

After hardware test 04, the original BOOT was restored. Android boot completion and unlocked state were verified, and all four partition hashes match the original backups. No compositor or flash remains running. Step 8 is committed as complete; step 9 has not started.

## Step 9 started — Arch compatibility and root image

- [x] Inspect current Arch Linux ARM and pinned Omarchy Mobile sources.
- [x] Confirm Arch glibc's declared minimum (3.7) and systemd's incompatible supported minimum (5.10).
- [x] Build a metadata-correct SSD-backed ext4 root image; disable ext4 features too new for 4.14.
- [x] Upgrade/install signature-checked Arch packages, including Hyprland 0.57.2 and Aquamarine 0.16.0.
- [x] Verify Arch commands and package inventory inside the ARM64 build container.
- [x] Build/inspect NBD-enabled kernel and independently packaged BOOT candidate.
- [x] Prove initial read-only USB/SSD root access and Arch commands on the tablet.
- [x] Prove non-root Hyprland with the working KGSL/SDE Mesa stack.
- [ ] Integrate portable Omarchy Mobile components and resolve unsupported services.

Current systemd 262.2 does not support this 4.14 kernel. BusyBox remains PID 1 during userspace testing; no full supported Arch/systemd/Omarchy boot is claimed. Details: docs/arch-userspace.md; initial evidence: docs/build-records/arch-bootstrap.json. No step 9 BOOT image has been flashed at this checkpoint.

Step 9 offline checkpoint: NBD-only config delta verified; new BOOT candidate structurally validated and previous candidate retained. Arch filesystem/NBD-server checks and non-root Hyprland config validation passed. The hardware test remains pending. Evidence: docs/build-records/arch-offline-validation.json.


### Step 9 hardware test 05 — partial success, recovery pending

The NBD-enabled BOOT booted and matched its readback hash. The initial read-only NBD/ext4 mount worked; native Arch glibc 2.43, bash, pacman queries and UID 1000 user were verified. The first graphics probe exited for a missing Vulkan loader. That signed package was added offline after unmounting/stopping the export. The subsequent NBD connection/mount attempt in the same boot lost USB/SSH responsiveness before another GPU probe started. Root cause is unknown. The mount helper now refuses a second connection per boot as containment, not as a proven fix.

Android filesystems were not mounted. Original BOOT has NOT yet been restored after test 05: physical Download Mode is required, and the user has been given the button sequence. Keep step 9 open. Evidence: docs/build-records/hardware-test-05.json. Next recovery work: restore original BOOT, verify Android and all four original hashes, and inspect pstore/last-kernel logs privately before further hardware experiments.

Test 05 recovery completed: user entered Download Mode; original BOOT restored, Android boot completion/unlocked state and all four original partition hashes verified. One pstore console was saved privately but is corrupted/incomplete and does not establish the stall cause. The NBD export is stopped. Next approach: prepare a compressed RAM-only Arch root while Android stays running; retain NBD evidence as an incomplete transport experiment.


### Step 9 — RAM-root offline checkpoint

- [x] Preserve the original NBD image and build a separate compressed RAM root.
- [x] Trim generic firmware/cache; include privately captured, hash-verified tablet GPU firmware.
- [x] Build the 328 MiB SquashFS/XZ image and pass read-only loop/chroot, non-root PTY/config and library checks.
- [x] Build and structurally validate a separate SquashFS kernel/BOOT candidate with NBD disabled.
- [x] Run the RAM-root Arch/Hyprland test on the tablet.

Android is currently restored and verified. The old NBD stall remains undiagnosed; it is removed from the new experiment path. Current systemd remains unsupported on kernel 4.14. Evidence: docs/build-records/arch-ram-offline-validation.json.


### Step 9 — native Arch and Hyprland hardware checkpoint (2026-11-15)

- [x] Verify reconnected SSD volumes and critical image hashes.
- [x] Boot the SquashFS-enabled kernel with NBD disabled; mount verified Arch root entirely in RAM.
- [x] Pass non-root Zink/Turnip GPU readback: 1,152 red pixels, 2,944 blue pixels.
- [x] Diagnose DRM enumeration: Arch libudev 262 returns -49; isolated libudev 257 enumerates card0 as root and UID 1000.
- [x] Run Hyprland 0.57.2 as UID 1000 for 120 seconds with a mapped foot terminal; wrapper exits zero.
- [x] Restore Android; verify boot completion, unlocked state and all four original partition hashes.
- [ ] Integrate Omarchy components and resolve unsupported services.

User confirmed the Hyprland terminal and updating clock were visible during the bounded session. Touch, pen and long-duration stability remain unvalidated. BusyBox remains PID 1; systemd 262 requires kernel >=5.10 and is unsupported on this 4.14 kernel. Step 9 remains open. Evidence: docs/build-records/hardware-test-06.json. Next: make the compatibility prefix reproducible in the RAM image, then inspect portable Omarchy shell dependencies before another bounded hardware test.


### Step 9 — Omarchy shell image prepared

- [x] Pin Omarchy 4.5.0-3 and its Quickshell runtime; verify detached signatures against the pinned HTTPS-bootstrapped keyring.
- [x] Preserve the proven Arch image; build a separate 582 MiB RAM image with the compatibility libudev prefix.
- [x] Include the real Omarchy shell host, mobile bar and an isolated profile with idle/lock disabled.
- [x] Check Quickshell libraries/version and Hyprland profile offline.
- [ ] Validate Omarchy host and mobile bar on the native tablet.

User authorizes keeping the tablet in native Linux testing mode between tests; routine Android restoration is no longer required. Original recovery images remain retained. Systemd, input and hardware services remain unresolved. This image extracts runtime payloads without installing the full Omarchy package or running its installer/hooks. Evidence: docs/build-records/omarchy-root-build.json.
