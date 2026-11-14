# Progress

- [x] Read-only SM-P613 hardware audit.
- [x] Pin and fetch the exact running kernel source.
- [x] Review Samsung restrictions and ROM installation/upgrade history.
- [x] Inspect matching recovery/vbmeta release archive offline.
- [x] Create plan, architecture and development steps.
- [x] 1. Validate local ARM64 Linux kernel builder.
- [x] 2. Generate and compare unchanged vendor configuration.
- [ ] 3. Compile and inspect unchanged kernel/device-tree outputs.
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

Next: step 3, compile unchanged kernel and device trees with LLVM 19. No image has been flashed.
