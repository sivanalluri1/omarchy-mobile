# Development steps

Run from the repository root. Build/package scripts do not flash or reboot the tablet.

## Storage and builder

Follow docs/storage.md to attach the case-sensitive SSD image and configure ignored storage.local.env. The source and build output now use SSD bind mounts; original Docker volumes are fallback copies.

```sh
docker build -t omarchy-p613-builder:llvm19 -f buildenv/Dockerfile .
bash scripts/prepare-linux-source.sh
```

The source preparer fetches the pinned revision into case-sensitive storage if absent and refuses a different or modified checkout. Compiler/package evidence is under docs/build-records.

## Baseline (completed)

```sh
bash scripts/kernel-build.sh configure baseline
bash scripts/kernel-build.sh build baseline
```

Vendor configuration matched the live tablet. Original source compiled unchanged with LLVM 19 and the external DTC override. Do not compile the case-colliding macOS source checkout.

## Minimal Linux (completed offline)

```sh
docker build -t omarchy-p613-initramfs:debian13 -f buildenv/initramfs.Dockerfile buildenv
bash scripts/build-initramfs.sh
bash scripts/kernel-build.sh configure minimal
bash scripts/kernel-build.sh build minimal
```

Read docs/minimal-linux.md for generated keys, RAM-only logging, USB-local DHCP and key-only SSH. These builds do not prove a tablet boot.

Inspect a kernel build by mounting the SSD checkout as /checkout, the desired build directory as /out, and running scripts/inspect-kernel-build.py inside the kernel builder. Inspect the archive with scripts/inspect-initramfs.py. Keep the resulting metadata in docs/build-records.

## Packaging and hardware gate

Follow docs/boot-experiment.md once present. Packaging is separate from device writes. Before hardware testing, review the candidate hash, explicit BOOT target, backup hash, tool command and physical rollback path. Native boot and USB/SSH are checked off only after hardware evidence.


## Graphics bring-up (step 8 hardware proof completed)

```sh
docker build -t omarchy-p613-graphics:debian13 -f buildenv/graphics.Dockerfile .
bash scripts/build-graphics-probes.sh
```

Read docs/graphics-bringup.md for hardware evidence and bounded display-test usage. Native CPU colour bars, hardware Vulkan compute, Zink/EGL triangle readback and continuously animated Weston output are verified. Follow the full patched-stack recipe in docs/graphics-bringup.md. Arch/Hyprland/Omarchy remain step 9 work.


Step 9 hardware checkpoint (2026-11-15): read-only Arch SquashFS in RAM, non-root GPU readback and bounded Hyprland passed using an isolated libudev 257 prefix. Android restored and all four original partition hashes verified. Omarchy integration and service compatibility remain open; see docs/arch-userspace.md and docs/build-records/hardware-test-06.json.


For the current Omarchy host/mobile-bar RAM profile, pinned inputs, parent-side Qt bootstrap and bounded/extended launcher, follow docs/omarchy-shell.md. The complete phone service graph and input validation remain subsequent work.


Current mobile profile: RAM udev classifications and volatile pen resolution metadata feed libinput/Hyprland. The mobile desktop launches entries through GIO in the manual session and uses static recents cards. The GPU prefix includes the separately validated Turnip allocation-fd ownership repair. Revision 5 passed clean-session and app lifecycle checks; follow docs/input-bringup.md and docs/build-records/hardware-test-08.json. On-screen keyboard and full service/hardware integration remain open.


## Current prototype and power workflow (2026-11-17)

Step 9's native mobile prototype is validated through revision 12: home/launcher/recents, keyboard, touch/S Pen, Wi-Fi controls, built-in audio and battery percentage. The earlier entries above record the historical gates. Step 10 remains in progress; BusyBox supervises services manually.

Follow docs/network-services.md, docs/audio-bringup.md and docs/power-bringup.md for the current service order and test limits. Start system D-Bus, supplicant and NetworkManager before the desktop. Native BOOT stays in place; restage the RAM root after a reboot. Do not routinely restore Android.

The power probes are built with `bash scripts/build-power-probe.sh`. Deep sleep requires physically disconnecting USB; the tested desktop sequence disables Wi-Fi temporarily. Optional DBMDX firmware staging uses `python3 scripts/stage-power-firmware.py` before mounting Arch and remains a separate experiment. With that firmware loaded, the minimal Power-button trial passed using `P613_POWER_KEY_PM_ASYNC=0`; the test restores the prior setting. No automatic sleep/lock policy is enabled. Headphone checks remain deferred until hardware is available.
