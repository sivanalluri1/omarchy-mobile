# SM-P613 development plan

Target: native Linux and eventually Omarchy on Samsung SM-P613 (gta4xlveu). Start from the exact running LineageOS kernel source. Each completed gate is recorded in PROGRESS.md and committed/pushed; failures remain explicitly incomplete.

1. Establish and validate a local ARM64 Linux build environment with recorded compiler provenance.
2. Generate the unchanged vendor configuration and compare it with the running configuration.
3. Compile the unchanged kernel, DTBs and overlay blobs; validate architecture, sizes and source cleanliness. A successful build does not establish bootability.
4. Complete recovery preparation: installed-image inspection, physical USB/Download Mode status and a reviewed restoration set. Requires a deliberate hardware session; no flashing is part of steps 1–3.
5. Introduce a minimal Linux configuration and initramfs for USB NCM networking and authenticated SSH, with Android storage untouched.
6. Package the experiment using verified Samsung boot/AVB/DTB conventions. Review exact partition changes and recovery procedure before hardware testing.
7. Establish native boot and USB/SSH on the tablet; preserve recovery and record evidence.
8. Investigate KMS and Mesa/KGSL compatibility; prove visible output, then hardware-accelerated Wayland.
9. Integrate a compatible Arch Linux ARM userspace and Omarchy Mobile packages.
10. Validate touch, S Pen, networking, audio, charging and suspend individually.

Storage: about 59 GiB is free on the internal disk at setup. Use bounded build parallelism and one source/output baseline. Request the external SSD before a full Android checkout, additional large toolchains, or when free space approaches 20 GiB. Keep toolchains and output disposable; track metadata and scripts in Git.

See ARCHITECTURE.md for boundaries and STEPS.md for local operations. See docs/samsung-boot-research.md for evidence and unresolved boot restrictions.

## Current storage and execution gate

Large artifacts and builds now use /Volumes/siva_ssd/Development/Omarchy through the case-sensitive SSD build image. The Git repository remains at its original path. Milestones 1–8 have passed, including native boot, CPU panel output, hardware compute/graphics and accelerated Weston. The original Android BOOT is restored after hardware tests. Step 9 starts with a compatibility audit of Arch Linux ARM, systemd and Hyprland against kernel 4.14; no full Omarchy installation has been attempted. See docs/boot-experiment.md for concrete hashes and commands.
