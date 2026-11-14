# Recovery preparation — SM-P613

## Verified over physical USB

- USB ADB identified the SM-P613 running LineageOS 23.2-20260820.
- Existing Magisk 31.0 root access was granted; no root software was installed.
- Read-only captures of boot, recovery, DTBO and vbmeta were saved privately under ignored work/device-backups. Each file's byte count and SHA256 were checked against the device.
- Installed recovery and DTBO match the matching ROM ZIP exactly. Recovery ramdisk prop.default identifies 23.2-20260820. An older recovery log mentions January; it is historical and does not identify the current recovery.
- Installed boot differs from the release ZIP. Magisk is installed, so root patching is a plausible explanation, not a complete binary-diff analysis.
- Installed vbmeta differs from the downloaded recovery TAR, but its parsed flags are 3 and rollback index 0. Preserve this exact installed image rather than substituting the TAR's vbmeta.

Metadata: [installed-image inventory](build-records/installed-image-inventory.json). Raw images are not uploaded to GitHub. The read-only capture procedure is preserved in scripts/backup-installed-images.py; it refuses to overwrite existing backups.

## Download Mode USB round trip verified

After a short USB-enumeration delay, samloader 2.2.0 and Heimdall 2.2.2 detected the Samsung device. samloader print-pit --no-reboot successfully opened a protocol session and read 90 partition entries. BOOT and RECOVERY each have 24,576 blocks, DTBO 6,144, and VBMETA 16; the corresponding read-back sizes agree with a 4096-byte block size. This is partition-table inspection, not a write test.

The user reported no small status text visible on the Downloading screen, so named OEM/KG/FRP/SWREV values were not captured. The diagnostic response exposed model/serial only; raw diagnostics remain private. Do not infer named KG state from the Android numeric property.

A second tool connection failed its handshake after the no-reboot session. The user exited with Power + Volume Down until the display went black, then released the buttons. Android and physical USB ADB returned; sys.boot_completed=1 and ro.boot.flash.locked=0 were verified. Use the tested physical exit rather than assuming a repeated protocol session automatically works.

The official samloader 2.2.0 universal macOS ZIP digest was verified as 74578787146ad284ad285b00c1270b7db0ff8d31576f19159103bb1bf56cf808. Version/help/detect/PIT and firmware-query/download commands have run; no flash operation has run. No erase, repartition or sales-code change was requested.

## Restoration design constraints

The first kernel experiment should change only its reviewed target image and preserve known-good recovery, DTBO and vbmeta. Keep the exact captured boot image for returning to the current rooted installation; the stock ROM ZIP boot image is different. A rollback procedure is not validated until the transfer tool and Download Mode connection work. Matching full stock Samsung firmware is not yet downloaded or verified, so a complete factory-restoration set is also outstanding.

No partition write or data erase has been performed. Step 4 remains incomplete.

## Reviewed BOOT-only rollback draft

If a later reviewed experiment changes only BOOT and leaves recovery/DTBO/vbmeta/firmware/userdata unchanged, the candidate rollback is to enter the already-tested Download Mode and use samloader's explicit `--partition BOOT` mapping with the exact captured boot image. Verify its inventory hash and full partition size first. No PIT, erase, skip-size-check, CSC or bulk AP operation belongs in that narrow rollback.

This is a reviewed command mapping from tool help and the tablet PIT, not a tested restore write. Never apply this narrow procedure if the experiment changes other partitions. Hardware testing remains deferred until image packaging and the exact change set are reviewed.

## Factory recovery package

Samsung's service lists SM-P613/XAC firmware P613XXS8CYE1/P613OXM8CYE1/P613XXS8CYE1/P613XXS8CYE1, matching the running bootloader. Download completed into ignored work/research/stock. Archive SHA256 is recorded in build-records/factory-firmware-inventory.json and all ZIP entries passed CRC checks. Nested TAR.MD5 verification and package-content review remain pending. The factory package is a separate fallback from the exact rooted LineageOS partition captures.

## Paused checkpoint

Paused at the user's request pending the external SSD. No new build or storage move is authorized until resumption. Installed boot section comparison confirms kernel and DTB bytes match the LineageOS release; ramdisk differs. See build-records/installed-boot-section-comparison.json. Tablet is back in Android; no partition write or erase occurred.
