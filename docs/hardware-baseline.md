# SM-P613 audit findings

Read-only inspection completed over wireless ADB. No root requested, no reboot or flash performed.

- Model: SM-P613; device gta4xlveu; platform atoll.
- Installed ROM: LineageOS 23.2, unofficial build dated 2026-08-20. This corrects the earlier assumption that the running ROM might be LineageOS 24.
- Kernel: 4.14.357-openela-perf-g21b136df1533, aarch64.
- Bootloader: P613XXS8CYE1; verified boot state orange.
- Slot suffix empty; separate boot and recovery partitions observed, with dtbo. Do not use Pixel slot-B installation assumptions.
- Adreno618v1 reported by KGSL sysfs.
- /dev/kgsl-3d0, /dev/dri/card0 and /dev/dri/renderD128 exist. Both DRM nodes resolve to the display controller; renderD128 alone does not demonstrate Mesa-compatible GPU acceleration.
- Display driver binding: msm_drm; DSI-1 connector present. Connector status/modes were denied to the ADB shell.
- Touchscreen exposes multitouch coordinates 0–1199 by 0–1999.
- sec_e-pen exposes pressure 0–4095 and tilt axes. This establishes input capabilities reported by Android, not native Linux session validation.
- Live kernel config successfully extracted. DRM/MSM/SDE, KGSL, initramfs gzip and USB configfs NCM enabled. DEVTMPFS, FHANDLE and VT disabled; ECM and RNDIS disabled.
- Some partition, USB and sysfs inspection denied by Android permissions. A su executable exists; root availability was not tested.

## Development implications

Use the running kernel commit and the matching LineageOS 23.2 sources as the initial reproducibility target. Kernel features need review before general-purpose Linux userspace: devtmpfs and file-handle support are disabled, and no VT console is available. Minimal initramfs bring-up can avoid a full desktop init system and target NCM networking first.

Next source task: resolve commit g21b136df1533 and its matching device tree, inspect downstream DRM/KGSL userspace interfaces, and prepare a reproducible Linux build environment. Obtain the matching ROM boot/recovery/DTBO/vbmeta files and verify the recovery procedure before any boot-image experiment. No native boot or hardware-accelerated Wayland has been demonstrated.

Raw audit files are kept locally under work/ rather than included in this shareable summary.
