# SM-P613 installation and boot-chain research

Reviewed 2026-11-14. Research only: builds and device changes are paused at the user's request. No image was flashed, no root was requested, and the tablet was not rebooted.

## Scope and confidence

Read all seven pages of the LineageOS 23 Qualcomm thread in Chrome, including the expanded installation sections. Also reviewed the LineageOS 24 opening discussion and second page, the complete nine-step Exynos installation guide, the DSU proof-of-concept discussion, release metadata and pinned device sources. Direct XDA retrieval returned 502 and the wiki returned 403; Chrome could read both.

Maintainer instructions, user reports, source declarations, artifact inspection and live-device observations are distinguished below. Community success reports are evidence of a possible route, not a guarantee for our tablet. This is a research record, not a command sequence to execute.

## 1. ROM history relevant to our baseline

| Build | Maintainer's changes / relevant reports | Source |
| --- | --- | --- |
| 23.0 / 2025-07-28 | Android 16; DT2W ghost-touch fix; S Pen pointer change | [opening posts](https://xdaforums.com/t/rom-unofficial-2022-model-lineageos-23-for-galaxy-tab-s6-lite-2022-qualcomm.4752160/) |
| 23.0 / 2025-09-05 | August patch, microphone fix with voice activation, SM8150 common-kernel merge and config cleanup | [post 90270186](https://xdaforums.com/posts/90270186/) |
| 23.0 / 2025-11-22 | November patch, common-kernel updates, 4 GB zram | [post 90380850](https://xdaforums.com/posts/90380850/) |
| 23.2 / 2026-01-26 | Android 16 QPR2, January patch and LMKD tuning; network-traffic indicator broken | [post 90462219](https://xdaforums.com/posts/90462219/) |
| QPR2 upgrade failures | Maintainer associated some fastboot fallbacks with incompatible root patches. Users reported Lygisk 29.0 failing and 30.6 succeeding. Historical compatibility evidence, not a universal version prescription | [page 4](https://xdaforums.com/t/rom-unofficial-2022-model-lineageos-23-for-galaxy-tab-s6-lite-2022-qualcomm.4752160/page-4) |
| 23.2 / 2026-03-28 | Codec2 migration to fix multimedia decoding; hotspot fix; kernel and security updates | [post 90538735](https://xdaforums.com/posts/90538735/) |
| 23.2 / 2026-08-20 | Our installed build: August patch, common-kernel update, GCC-free kernel build, recovery redesign | [post 90703786](https://xdaforums.com/posts/90703786/) |
| 24.0 / 2026-10-24 | Separate Android 17 release; current release supplies August 23.2 recovery because the 24 recovery package has issues | [release](https://github.com/danielml3/releases/releases/tag/lineage-24.0-20261024-UNOFFICIAL-gta4xlveu-1792865481) |

User reports also mention palm rejection, stylus X tilt, orientation, tethering and drain issues. These are test targets, not established failures on this unit. In particular, USB NCM being enabled in our kernel configuration does not prove working tethering: later users still report tethering problems. [Pages 3–7 of the Qualcomm thread](https://xdaforums.com/t/rom-unofficial-2022-model-lineageos-23-for-galaxy-tab-s6-lite-2022-qualcomm.4752160/page-3).

## 2. What the Qualcomm installation actually does

The maintainer's SM-P613/P619 route has two distinct phases:

1. Unlock if needed; after the wipe, boot stock setup, connect to the Internet and verify OEM unlocking remains enabled and greyed out. Our device already runs LineageOS, so this is historical context, not a step to repeat.
2. Install the maintainer's recovery TAR using Odin's AP field. The TAR bundles recovery and patched vbmeta. Enter custom recovery immediately; booting OneUI may restore stock recovery. The documented key combinations require a physical connection to a computer.
3. Install the ROM ZIP from recovery with ADB sideload; a fresh install includes formatting data. Install optional matching GApps before the first system boot. An upgrade is a separate procedure and must not inherit the fresh-install wipe automatically.

Source: [maintainer's expanded instructions](https://xdaforums.com/t/rom-unofficial-2022-model-lineageos-23-for-galaxy-tab-s6-lite-2022-qualcomm.4752160/).

### Upgrades and post-install patches

- The maintainer confirms that enabling automatic recovery updates allows an OTA to update recovery after booting the installed OS. Recovery is therefore not necessarily permanent across updates. [post 90546181](https://xdaforums.com/posts/90546181/)
- GApps, Android root patches, AVB metadata and kernel patches serve different purposes. GApps/root are not prerequisites for native Linux boot. Old advice to always use Lygisk rather than Magisk is contradicted by later reports of both working at particular versions. [page 4](https://xdaforums.com/t/rom-unofficial-2022-model-lineageos-23-for-galaxy-tab-s6-lite-2022-qualcomm.4752160/page-4)
- For stock Samsung rooting, current Magisk documentation describes patching the matching AP package, and distinguishes initial wipe from HOME_CSC upgrades. It warns against mixing individual stock boot/recovery/vbmeta partitions into the patched installation. That stock-firmware procedure must not be copied onto this LineageOS/native-Linux project. Recovery-based Magisk installation is deprecated upstream. [Magisk installation guide](https://github.com/topjohnwu/Magisk/blob/master/docs/install.md#samsung-devices)
- A sideload progress value alone is inconclusive. The official wiki notes that 47% may accompany success. Add-ons can require a signature confirmation; an unexpected ROM signature error needs provenance/integrity checks. [official reference](https://wiki.lineageos.org/devices/gta4xlwifi/install/)

## 3. Samsung restrictions are several separate mechanisms

| Mechanism | Meaning for our work | Evidence |
| --- | --- | --- |
| Hardware Secure Boot | Samsung's boot ROM and signed bootloader chain remain trusted components. Our route uses the existing unlocked bootloader to load a custom OS image; it does not require replacing PBL/XBL/ABL | [Samsung hardware-backed security](https://docs.samsungknox.com/admin/fundamentals/whitepaper/samsung-knox-mobile-security/system-security/hw-backed-security/) |
| OEM lock / unlock permission | OEM-unlocking permission and an actually unlocked bootloader differ. A developer-options toggle alone is insufficient | [Magisk Samsung requirements](https://github.com/topjohnwu/Magisk/blob/master/docs/install.md#requirements) |
| Knox Guard / RMM | A separate policy gate may prevent unofficial images despite other unlock settings. Capture actual Download Mode status; do not translate an undocumented numeric property into a named state | [Magisk Samsung requirements](https://github.com/topjohnwu/Magisk/blob/master/docs/install.md#requirements) |
| AVB / vbmeta | Signed metadata describes trusted images. The device tree explicitly generates top-level vbmeta with flags 3; this concerns OS verification, not removal of Samsung's hardware root of trust | [AVB format](https://android.googlesource.com/platform/external/avb/+/master/README.md), [device BoardConfig](https://github.com/gta4xlve-dev/android_device_samsung_gta4xlveu/blob/20c5a3962c87f5c795049d880487eb7efdf39202/BoardConfig.mk) |
| dm-verity | Verifies filesystem blocks using hash trees; distinct from authenticating a kernel/boot image | [AVB documentation](https://android.googlesource.com/platform/external/avb/+/master/README.md) |
| Bootloader rollback prevention | Samsung hardware records minimum accepted bootloader revisions. Updating firmware can prevent returning to an older bootloader | [Samsung rollback fuses](https://docs.samsungknox.com/admin/fundamentals/whitepaper/samsung-knox-mobile-security/system-security/hw-backed-security/#knox-rollback-protection-fuses) |
| AVB rollback indices | AVB also has image rollback indices. These are separate from Samsung bootloader revision fuses. Generic unlocked-mode AVB behavior does not establish that Samsung firmware downgrade restrictions disappear | [AVB documentation](https://android.googlesource.com/platform/external/avb/+/master/README.md) |
| Knox Warranty Bit | Persistent hardware tamper record; returning to stock does not reset it. This is distinct from current OEM lock state | [Samsung Warranty Bit](https://docs.samsungknox.com/admin/fundamentals/whitepaper/samsung-knox-mobile-security/system-security/hw-backed-security/#knox-warranty-bit) |
| Android file encryption | Android userdata is encrypted; a native initramfs cannot assume it can mount that existing filesystem as a plaintext root | live device plus [recovery fstab](https://github.com/gta4xlve-dev/android_device_samsung_gta4xlveu/blob/20c5a3962c87f5c795049d880487eb7efdf39202/recovery.fstab) |

Do not relock with custom images installed. A page-7 user reported a boot failure after trying this and eventually restored stock. We have no tested custom-key/relock route for SM-P613. [report](https://xdaforums.com/posts/90808967/).

### A misleading error we must account for

The LineageOS 24 thread contains reports of the 24 recovery TAR producing an OEM-lock recovery error and image-extraction failure. Those users could run 23.2 and/or upgrade through its recovery. The maintainer later replaced the 24 release recovery package with 23.2. The exact root cause was not established in the reviewed material. Treat recovery format, vbmeta and bootloader compatibility as investigation targets; do not state that an OTA definitely relocked the bootloader. [24 discussion](https://xdaforums.com/t/rom-unofficial-2022-model-lineageos-24-for-galaxy-tab-s6-lite-2022-qualcomm.4806288/), [maintainer replacement notice](https://xdaforums.com/posts/90808815/).

## 4. What is confirmed on this tablet

The additional read-only ADB check reports:

```text
ro.boot.flash.locked=0
ro.boot.verifiedbootstate=orange
ro.boot.warranty_bit=1
ro.boot.kg=0x1
ro.boot.em.model=SM-P613
ro.boot.bootloader=P613XXS8CYE1
ro.crypto.state=encrypted
ro.crypto.type=file
```

This corroborates an unlocked, modified system with file encryption and a set warranty-bit property. It does not inspect hardware fuses directly. The meaning of kg=0x1 is unverified. Several vbmeta/verity properties are empty, so they do not prove which flags the flashed vbmeta currently contains. Download Mode OEM/KG/FRP/SWREV status and installed recovery version remain unverified; no reboot was performed to obtain them.

## 5. Source-level consequences for image generation

Pinned device revision: `20c5a3962c87f5c795049d880487eb7efdf39202`.

- BoardConfig declares boot header v2, 4096-byte pages, an embedded DTB, a separate DTBO, and a 96 MiB boot/recovery partition budget. Compare these declarations against actual release headers before constructing images.
- `BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3`. In libavb, bit 0 disables hashtree verification and bit 1 disables verification. This describes generated metadata, not proof of installed partition contents. [flag definitions](https://android.googlesource.com/platform/external/avb/+/master/libavb/avb_vbmeta_image.h)
- Recovery is configured for a SHA256_RSA4096 AVB footer using the AOSP test key and rollback index/location 1. This is not Samsung signing and does not imply locked-boot acceptance.
- `build/tasks/recoverytar.mk` explicitly packages `recovery.img` and `vbmeta.img` together.
- `releasetools.py` explicitly writes DTBO during OTA installation and asserts SM-P613/P619 identity. A ROM upgrade can therefore change more than system and boot. Do not use broad ROM installation as a shortcut for testing one kernel.

Sources: [BoardConfig](https://github.com/gta4xlve-dev/android_device_samsung_gta4xlveu/blob/20c5a3962c87f5c795049d880487eb7efdf39202/BoardConfig.mk), [recovery TAR recipe](https://github.com/gta4xlve-dev/android_device_samsung_gta4xlveu/blob/20c5a3962c87f5c795049d880487eb7efdf39202/build/tasks/recoverytar.mk), [OTA hooks](https://github.com/gta4xlve-dev/android_device_samsung_gta4xlveu/blob/20c5a3962c87f5c795049d880487eb7efdf39202/releasetools.py).

## 6. Exynos reference: reusable concepts, different artifacts

The official gta4xlwifi guide supports SM-P610, Exynos 9611. It is not an SM-P613 guide. It currently requires Android 13 vendor firmware and uses samloader-rs for Download Mode flashing; do not transfer that firmware requirement or its recovery image to P613.

Useful shared concepts are checking the exact model, preserving a firmware recovery route, connecting USB for key-combination recovery entry, entering custom recovery immediately after flashing, distinguishing fresh-install formatting from upgrades, and verifying installation in recovery. The reviewed P610 guide has no separate vbmeta step, whereas the P613 maintainer explicitly bundles vbmeta. This difference must be preserved.

samloader-rs advertises macOS support, so our Mac has a potential native flashing-tool option. That capability has not been tested with this SM-P613; Linux Odin4 and Heimdall reports in the P613 thread include both failures and successes. A user's transport timeout was eventually resolved using Odin on a PC; this does not establish that secure boot had to be disabled.

Sources: [P610 overview](https://wiki.lineageos.org/devices/gta4xlwifi/), [P610 installation](https://wiki.lineageos.org/devices/gta4xlwifi/install/), [samloader-rs](https://github.com/topjohnwu/samloader-rs), [P619 transport report and resolution](https://xdaforums.com/posts/90706777/).

## 7. DSU proof of concept

The author specifies ROManitas base/kernel, not our current LineageOS installation. The thread lists video-camera, rotation and Chrome problems, and explicitly discontinues development. AlfCraft07 describes it as Android with a desktop interface. It offers reference material for Android compatibility, not evidence of a Mesa/Hyprland native-Linux port. No DSU image was installed or executed. [DSU thread](https://xdaforums.com/t/proof-of-concept-p613-dsu-googlebookos-aluminum-os-android-17.4806184/).

## 8. Revised next steps — deferred until development resumes

1. Finish artifact analysis: inspect the matching 23.2 recovery/vbmeta package; obtain matching boot and DTBO from the installed ROM release, recording URLs and SHA256 values. Check headers, command line, DTB placement and AVB metadata. A locally computed hash is not an independent publisher signature.
2. Record the installed recovery version and Download Mode OEM/KG/FRP/SWREV information when a deliberate device-session change is planned. Verify physical USB and the restoration route first; wireless ADB alone cannot recover a nonbooting OS.
3. Establish a known-good restoration set and matching stock firmware availability without upgrading bootloader components. The current bootloader remains P613XXS8CYE1; do not assume any older or newer firmware package is interchangeable.
4. Resume the unchanged-kernel build only after this research phase. Keep its source/config/toolchain provenance separate from experimental Linux changes.
5. Design a minimal initramfs image preserving known boot packaging and DTB/DTBO compatibility. Keep encrypted userdata untouched. Preserve a functioning recovery; do not assume fastboot boot, Pixel A/B slots, or direct SD/USB boot is available.
6. Test USB networking/SSH before Linux desktop integration. Root patches and generic multidisabler/AVB-fixer ZIPs are not default prerequisites. Any required verification change must be explained against the exact image set, not applied blindly.

Unresolved: exact original 24 recovery failure cause; actual flashed vbmeta; exact installed recovery version; Download Mode policy state; original ROM toolchain; usable temporary-boot method; native graphics compatibility. These gaps prevent calling a flashing procedure verified.

## 9. Downloaded recovery package inspected offline

Downloaded the August 20, 2026 recovery TAR from the matching release. Its SHA256 matches GitHub's asset digest (`c4659d851feb21edfdcdf3c4c254fe75db5bd7deff7d78c84400f086a9517639`). It contains exactly `recovery.img` (100,663,296 bytes) and `vbmeta.img` (65,536 bytes).

The recovery has Android boot header v2, header size 1660 and 4096-byte pages. It includes a ramdisk, recovery DTBO and DTB. Their page-aligned sizes agree with the original-image size recorded in its AVB footer. Top-level vbmeta has flags 3 and rollback index 0. Recovery's own AVB metadata has flags 0 and rollback index 1: the two metadata objects must not be conflated.

See [inspection data](recovery-artifact-inspection.json) for sizes, hashes, metadata and command line. Parsing used the [AOSP boot header layout](https://android.googlesource.com/platform/system/tools/mkbootimg/+/refs/heads/main/include/bootimg/bootimg.h) and [AVB header layout](https://android.googlesource.com/platform/external/avb/+/master/libavb/avb_vbmeta_image.h). This checks structure and a distribution digest, not the image's cryptographic signature or whether it matches installed partition bytes. The TAR remains ignored under work/research; no downloaded image was flashed or executed.
