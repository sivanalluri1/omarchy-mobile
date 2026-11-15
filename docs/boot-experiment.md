# First BOOT-only hardware test — review before writing

## Candidate

- File: /Volumes/OmarchyBuild/build/boot-experiment/boot.img, stored in the SSD sparsebundle.
- Bytes: 100,663,296 (96 MiB), matching the installed BOOT partition and PIT.
- SHA256: 9b6355d7a4380b418d7491219c19dc54051a008e6ab1544fe3df5431d6a93be5.
- Kernel: minimal configuration, clean pinned Samsung source, Debian LLVM 19.1.7. This differs from the installed ROM's LLVM 21 toolchain.
- Ramdisk: RAM-only init, USB NCM/DHCP and key-only SSH. Early userspace log: /bringup.log.
- Header v2, 4096-byte pages; installed load addresses, OS compatibility fields, board name and command line preserved.
- Exact installed DTB reused. Existing recovery, DTBO, vbmeta, bootloader and encrypted userdata are outside the planned write set.
- Unsigned AVB algorithm NONE and flags 3 match the current Magisk-patched BOOT metadata. This is not a signed/trusted OS image. AOSP avbtool verified the footer and embedded SHA256 descriptor; it does not prove bootloader acceptance.

Evidence: build-records/boot-experiment-validation.json. Update: the authorized first test passed on hardware and the exact original BOOT was restored. See hardware-test-01.md.

## Rebuild offline

```sh
python3 scripts/fetch-aosp-tools.py
# Kernel and initramfs must first match their recorded validation hashes.
python3 scripts/package-boot-experiment.py
```

The tool lock records immutable AOSP release tags and source hashes. Packaging refuses an altered template or a kernel/ramdisk different from the inspected records. It compares embedded payload bytes, headers and DTB and verifies the AVB hash. The output is a private artifact because its ramdisk includes an SSH host key.

## Preconditions for hardware testing

Obtain the user's explicit go-ahead for a first BOOT-only experiment and restoring Android afterward. Keep the USB cable and SSD connected, ensure adequate battery and retain access to this Mac's tools/backups. Check the current model, OS, unlock state and boot/recovery/DTBO/vbmeta hashes against the captured inventory before writing. Stop if any changed.

The Download Mode transport/PIT read and physical return to Android were tested. A repeated protocol connection after print-pit --no-reboot failed once, so start each write from a fresh Download Mode entry and do not open a PIT session immediately before flashing. Named OEM/KG/FRP/SWREV screen fields were not visible. Do not treat their absence as a known policy state.

## First test procedure (executed successfully)

1. Enter Download Mode from the currently working Android ADB session. Wait for USB enumeration.
2. Use the verified samloader binary's explicit BOOT mapping with the candidate:

   `work/tools/samloader flash --partition BOOT /Volumes/OmarchyBuild/build/boot-experiment/boot.img`

3. Expect a minimal Linux experiment, not an Android or Omarchy desktop. The display may remain on the boot screen. Look for a newly enumerated NCM interface, a DHCP lease in 192.168.77.0/24 and SSH at 192.168.77.1. Do not modify the Mac's default route or DNS. If DHCP fails, inspect before making a host-network change.
4. Use the dedicated client key and pinned host key from docs/minimal-linux.md. Collect uname, /proc/mounts, /bringup.log, USB/network state and kernel logs. Do not mount Android filesystems. A container SSH self-test is not evidence of this hardware milestone.
5. Restore the original BOOT image after the first test, including after an unsuccessful boot, and verify normal Android/USB ADB return and image hashes.

No erase, PIT, repartition, CSC, AP, skip-size-check, bootloader update, vbmeta replacement, DTBO replacement or relock action belongs in this BOOT-only test.

## Exact rollback input

- File through the repository: work/device-backups/boot.img.
- SHA256: 15966f29996c7ab4c299d7b95f7a1e3ae04ef9ea788e4d11fc66f96eec2753ed.
- Full size: 100,663,296 bytes.
- Independent internal copy remains under work.internal/device-backups/boot.img.

From a fresh Download Mode entry, the reviewed narrow mapping is:

`work/tools/samloader flash --partition BOOT work/device-backups/boot.img`

If native USB is unavailable, use the documented Samsung physical button/USB method to enter Download Mode. Power + Volume Down forces a restart; it does not restore Android BOOT. The current custom BOOT image remains installed until the original image is written back. Do not relock. The matching full Samsung factory package is a separate fallback that can affect multiple partitions/data and is not the default rollback for this experiment.

This narrow BOOT rollback was exercised successfully during the first test and verified by Android boot completion plus all four original partition hashes. That result applies to this image set and does not guarantee recovery from unrelated changes.
