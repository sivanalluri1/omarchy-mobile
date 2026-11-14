# Recovery preparation — SM-P613

## Verified over physical USB

- USB ADB identified the SM-P613 running LineageOS 23.2-20260820.
- Existing Magisk 31.0 root access was granted; no root software was installed.
- Read-only captures of boot, recovery, DTBO and vbmeta were saved privately under ignored work/device-backups. Each file's byte count and SHA256 were checked against the device.
- Installed recovery and DTBO match the matching ROM ZIP exactly. Recovery ramdisk prop.default identifies 23.2-20260820. An older recovery log mentions January; it is historical and does not identify the current recovery.
- Installed boot differs from the release ZIP. Magisk is installed, so root patching is a plausible explanation, not a complete binary-diff analysis.
- Installed vbmeta differs from the downloaded recovery TAR, but its parsed flags are 3 and rollback index 0. Preserve this exact installed image rather than substituting the TAR's vbmeta.

Metadata: [installed-image inventory](build-records/installed-image-inventory.json). Raw images are not uploaded to GitHub. The read-only capture procedure is preserved in scripts/backup-installed-images.py; it refuses to overwrite existing backups.

## Download Mode check in progress

Rebooted to Download Mode with adb reboot download. ADB disconnected as expected. Initial samloader 2.2.0 and Heimdall 2.2.2 detection did not see a compatible device. This does not establish an OEM/KG block: screen state and USB enumeration still need confirmation.

The official samloader 2.2.0 universal macOS ZIP was downloaded from topjohnwu/samloader-rs; SHA256 matched the GitHub asset digest 74578787146ad284ad285b00c1270b7db0ff8d31576f19159103bb1bf56cf808. Only version/help/detect commands have run; no flash operation has run.

Pending: OEM LOCK, KG STATUS, FRP LOCK, RP SWREV screen values; working Download Mode USB session; partition table read; verified return to Android. Keep the cable connected. Do not choose lock/unlock, erase, or repartition actions. If a normal exit is needed, Samsung's documented physical recovery route uses Power + Volume Down until the display goes black; do not choose a bootloader lock option.

## Restoration design constraints

The first kernel experiment should change only its reviewed target image and preserve known-good recovery, DTBO and vbmeta. Keep the exact captured boot image for returning to the current rooted installation; the stock ROM ZIP boot image is different. A rollback procedure is not validated until the transfer tool and Download Mode connection work. Matching full stock Samsung firmware is not yet downloaded or verified, so a complete factory-restoration set is also outstanding.

No partition write or data erase has been performed. Step 4 remains incomplete.
