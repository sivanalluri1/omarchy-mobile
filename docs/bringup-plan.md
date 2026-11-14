# SM-P613 native Linux / Omarchy bring-up

Status: read-only ADB audit and pinned source setup complete. Samsung boot-chain research and recovery artifact inspection complete; see samsung-boot-research.md. Builds are deferred at the user's request. No image built or flashed.

## First step
Connect the SM-P613 by USB, enable USB debugging and authorize this computer. Run:

```bash
bash audit-p613.sh
```

Run from the directory containing the script. It saves reports in a new local directory. It does not request root, reboot, read partition contents or flash anything. Some files may be inaccessible on production LineageOS; preserve those errors. Review reports for identifiers before sharing.

## Source choice
Start from the kernel revision matching the installed LineageOS build, once identified. Use gta4xlve-dev's device tree for boot header, DTB/DTBO and partition references. Its BoardConfig selects vendor/atoll-perf_defconfig plus vendor/gta4xlve.config, boot header v2, embedded DTB and separate DTBO. These are source declarations, not yet verified against this tablet.

The fetched atoll configuration enables DRM, Qualcomm KGSL, IKCONFIG_PROC, USB configfs and NCM; VT is disabled. This is not proof of compatibility with Mesa or Hyprland. Inspect the running kernel config and device nodes next. Presence of a DRM card alone does not prove GPU render-node support.

AlfCraft07's default branch is oneui/android17. Treat it as an alternative for comparing patches, not a drop-in replacement for the installed LineageOS kernel. The vendor repository default is lineage-23.2 while the device/kernel defaults inspected earlier are lineage-24.0: resolve matching revisions before any build. Proprietary Android libraries are not automatically usable by Arch/glibc applications.

## Milestones and exit criteria
1. Audit: identify exact OS/kernel, configs, partition names, display/KGSL/input/USB interfaces; obtain matching ROM boot/recovery/DTBO/vbmeta artifacts and document the tested recovery route. Do not assume Pixel A/B or fastboot procedures apply.
2. Minimal boot: reproduce the matching Android kernel build before changes, then create a separate minimal initramfs experiment with storage unmodified. First target: kernel boot and USB NCM networking with authenticated SSH. Establish the Samsung boot-image and recovery procedure before testing; no flash commands are provided yet.
3. Graphics: investigate display/KMS availability and GPU userspace ABI independently. Establish visible output first, then a small compositor test and verified hardware rendering. Software rendering can help diagnosis but does not satisfy the acceleration milestone. If downstream KGSL cannot support the desired stack, evaluate adaptation or a mainline SM7125/device port.
4. Integration: validate selected Arch Linux ARM userspace against the actual kernel's required features. Bring up a minimal session before adding Omarchy Mobile packages and device integration. Validate touch, S Pen, Wi-Fi, Bluetooth, audio, battery/charging and suspend separately; record hardware evidence for each claim.

## Outstanding evidence
Running-device audit completed; matching release recovery/vbmeta package inspected offline. XDA DSU thread reviewed in Chrome: it requires ROManitas base/kernel and is an abandoned Android desktop proof of concept. No reproducible kernel build, native boot, or graphics test yet. Actual installed recovery/vbmeta, Download Mode status and restoration procedure remain unverified.

## References
- https://github.com/derekross/omarchy-mobile
- https://github.com/gta4xlve-dev/android_device_samsung_gta4xlveu
- https://github.com/gta4xlve-dev/android_kernel_samsung_gta4xlve
- https://github.com/gta4xlve-dev/android_vendor_samsung_gta4xlveu
- https://github.com/AlfCraft07/android_kernel_samsung_sm7125
- https://xdaforums.com/t/proof-of-concept-p613-dsu-googlebookos-aluminum-os-android-17.4806184/
