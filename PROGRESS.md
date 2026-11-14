# Progress

- [x] Read-only SM-P613 hardware audit.
- [x] Pin and fetch the exact running kernel source.
- [x] Review Samsung restrictions and ROM installation/upgrade history.
- [x] Inspect matching recovery/vbmeta release archive offline.
- [x] Create plan, architecture and development steps.
- [x] 1. Validate local ARM64 Linux kernel builder.
- [x] 2. Generate and compare unchanged vendor configuration.
- [x] 3. Compile and inspect unchanged kernel/device-tree outputs.
- [ ] 4. Verify installed recovery, Download Mode status and restoration set.
- [ ] 5. Build minimal Linux configuration/initramfs with NCM and SSH.
- [ ] 6. Validate experimental Samsung image packaging and recovery procedure.
- [ ] 7. Prove native boot and USB/SSH on hardware.
- [ ] 8. Prove display and accelerated Wayland.
- [ ] 9. Integrate Arch Linux ARM and Omarchy.
- [ ] 10. Validate remaining tablet hardware.

## Current work

Step 1 passed: ARM64 Debian container built; clang/LLD 19.1.7, native executable and AArch64 object compilation verified. Evidence: docs/build-records/builder-validation.txt.

Step 2 passed: generated vendor configuration has zero symbol-value differences against the running tablet config. Evidence: docs/build-records/vendor-config-comparison.json.

The macOS checkout has case-colliding filenames. A fresh checkout from its Git objects is clean in Docker Linux storage; builds use that read-only source and case-sensitive output volumes. Earlier source-cleanliness claims applied insufficient validation and are superseded by this Linux checkout check.

Step 3 passed: unchanged source compiled with LLVM 19.1.7 and external DTC 1.7.2. Image header, AArch64 ELF, both device-tree blobs and source cleanliness verified. The 52,684,824-byte Image and artifact hashes are recorded in docs/build-records/kernel-baseline-artifacts.json.

Step 4 in progress: matching LineageOS ROM ZIP and recovery TAR downloaded and digest-verified. Boot/DTBO/recovery inventory recorded. User reports internal storage is backed up. The final ADB check found no connected device. Connect a USB data cable and authorize ADB before continuing. Installed recovery/vbmeta and Download Mode status remain to be checked. No flashing or reboot has been performed.

## Build compatibility notes

- Native ARM64 LLVM 19 differs from the installed ROM's Android LLVM 21; no byte-identical reproduction is claimed.
- The bundled DTC failed parsing the Samsung overlay. Using the supported DTC_EXT=/usr/bin/dtc override succeeded without source edits.
- CONFIG_BPFILTER is disabled in the baseline; the build's bpfilter linker-probe warning did not omit an enabled feature.
- About 40 GiB internal space remained after compilation and downloading the restoration ROM. External SSD is not yet required; request it before larger parallel baselines or approaching the 20 GiB threshold.
