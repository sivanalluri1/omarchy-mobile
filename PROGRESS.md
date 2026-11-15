# Progress

Status: native display colour-bar test passed with user confirmation. Step 8 remains open for GPU rendering and accelerated Wayland.

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
- [ ] 8. Prove display and accelerated Wayland.
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
- [ ] Prove GPU rendering through Turnip/KGSL without software fallback.
- [ ] Prove GPU/display buffer sharing and accelerated Wayland.

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
