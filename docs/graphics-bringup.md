# Graphics bring-up — SM-P613

Step 8 graphics proof passed: native panel output, hardware compute, graphics readback, GBM sharing and continuously animated Weston output. Arch/Hyprland/Omarchy and other tablet hardware remain separate milestones.

## Display milestone (hardware test 02)

On November 14, 2026 (America/Phoenix), the same validated RAM-only Linux BOOT image from test 01 booted successfully again. No kernel, DTB or persistent userspace changes were required for this test.

The static `native/graphics-probe.c` reported:

- DRM `msm_drm` 1.2.0, dumb-buffer support and PRIME import/export capability bits.
- Connected DSI connector 28: 1200 × 2000 at 60 Hz, pixel clock 157996 kHz.
- Compatible CRTC 100 and encoder 27.
- KGSL device information: chip ID `0x06010800` (Adreno 618), GMEM 524288 bytes.

`native/display-test.c` created an XRGB8888 dumb framebuffer, drew eight vertical colour bars with the CPU, and successfully set the DSI mode through legacy KMS. **The user confirmed that all colour bars were visible on the tablet.** The test has a 120-second limit and handles SIGINT/SIGTERM by restoring the previous framebuffer when one exists, or disabling its CRTC when the initial state has no framebuffer. It releases the framebuffer, mapping and dumb buffer afterward. This run was stopped after confirmation; its log showed no modeset/cleanup errors, but a background exit status was not captured.

The initial panel0-backlight brightness was 255 with maximum 425. No backlight value was changed by the probe. The extra virtual connector's advertised modes are not evidence of an external display output.

This proves native display output with CPU rendering. It does **not** prove GPU rendering, buffer sharing between KGSL and SDE, or an accelerated Wayland compositor.

Original BOOT was restored after the test. Android boot completion, unlocked state and all four original partition hashes were verified. No hardware test remains running.

## Firmware handling

Six firmware files were read from the existing Android installation and transferred over pinned-key SSH into the native RAM rootfs under `/lib/firmware` and the kernel's configured `/vendor/firmware_mnt/image` search path. No Android filesystem was mounted during native testing. The KGSL open/query succeeded; dmesg reported `a615_zap` brought out of reset. Firmware file hashes and original paths are recorded in `build-records/graphics-firmware.json`; binaries remain private and are not redistributed in this repository.

Unrelated audio-firmware timeouts and display/touch pinctrl warnings remain in dmesg. Visible display output succeeded despite those warnings; their impact on other hardware remains untested.

## Reproduce the local tools

```sh
docker build -t omarchy-p613-graphics:debian13 -f buildenv/graphics.Dockerfile .
bash scripts/build-graphics-probes.sh
```

The build uses the pinned kernel's KGSL UAPI header and static libdrm in the ARM64 container. Executables are written to the SSD build directory `build/graphics-probes`. The container has no tablet devices; the read-only probe's no-device failure was checked there before testing on hardware. The display tool requires the explicit argument `--show-120-seconds`; it is never run automatically by the build script.

On the already-authorized native test system, transfer tools and firmware into RAM using the existing pinned-key SSH workflow. Run `graphics-probe` first. A display test invocation is:

```sh
/tmp/display-test --show-120-seconds > /display-test.log 2>&1
```

Record the command's exit status as well as its log on future runs. Keep the known-good BOOT candidate and original BOOT backup unchanged. Follow the tested Download Mode / BOOT-only restoration procedure in `boot-experiment.md` afterward.

## Graphics gate investigated

The vendor kernel exposes separate SDE DRM and KGSL GPU interfaces. A DRM render node alone does not establish compatibility with a normal upstream Mesa/MSM driver.

Mesa's upstream `freedreno-kmds` option explicitly states that Gallium Freedreno does not support KGSL and recommends Zink with Turnip for that interface. The inspected upstream snapshot is `8899a7b4cf1e8b5dbce884f94b440e40e84ca26b`, version 26.2.0-devel. Its Turnip KGSL backend contains both DMA-heap and ION allocation paths. These are source observations, not a successful build or a claim that this exact kernel supports every required operation.

Primary source: [Mesa meson.options at inspected revision](https://chromium.googlesource.com/external/gitlab.freedesktop.org/mesa/mesa/+/8899a7b4cf1e8b5dbce884f94b440e40e84ca26b/meson.options), [Turnip KGSL backend](https://chromium.googlesource.com/external/gitlab.freedesktop.org/mesa/mesa/+/8899a7b4cf1e8b5dbce884f94b440e40e84ca26b/src/freedreno/vulkan/tu_knl_kgsl.cc).

These gates have now been verified in tests 03 and 04 below:

- [x] Build pinned Mesa Turnip with KGSL.
- [x] Prove hardware compute and graphics readback without software fallback.
- [x] Prove GBM/DMA-BUF export, KMS handle import and visible scanout.
- [x] Run an accelerated Wayland compositor with continuous visible animation.
- [ ] Evaluate Hyprland and compatible Arch/Omarchy userspace on kernel 4.14 (step 9).

Raw test logs remain private under the ignored hardware-test directories.

## Turnip build milestone

Pinned Mesa Turnip compiled for Linux AArch64 with `freedreno-kmds=kgsl`, no Gallium drivers and LLVM disabled. Source archive URL/revision/hash: `mesa.lock.json`. Preparation verifies existing source files against the checksum-verified archive. Build commands:

```sh
python3 scripts/prepare-mesa.py /Volumes/OmarchyBuild
bash scripts/build-turnip.sh configure
bash scripts/build-turnip.sh build
bash scripts/build-gpu-probes.sh
```

`native/gpu-compute.comp` writes 1,024 deterministic uint32 values. Its Vulkan host program refuses CPU/non-Qualcomm devices, submits a compute dispatch, waits on a bounded fence, invalidates mapped memory and checks every result. A forced Turnip-only ICD file prevents loading a software ICD. The runtime assembler copies the driver, loader and shared-library dependency closure into a RAM-transfer bundle. The no-device container test returned Vulkan initialization failure, as expected; it did not silently use software rendering. Build evidence: `build-records/turnip-build.json`. Actual tablet execution is recorded separately.


## Hardware test 03 — Vulkan compute passed

The native tablet loaded the checksum-verified Turnip-only runtime and reported `Turnip Adreno (TM) 618`, vendor `0x5143`, device `0x06010800`, integrated GPU, Vulkan 1.3.354. The compute pipeline compiled, dispatched and completed its fence. All 1,024 GPU-written values matched the CPU reference; the process returned zero. No CPU/software ICD was available in the runtime. This establishes real GPU shader execution, independently of display output.

Original Android BOOT was restored afterward; boot completion, unlocked state and all four original partition hashes were verified. No Android filesystem was mounted during the experiment. At the test 03 checkpoint, graphics rasterization and an accelerated compositor still required separate proof; test 04 below supplies it. Sanitized evidence: `build-records/hardware-test-03.json`.

## Hardware test 04 — accelerated rendering and Wayland

The GPU rendered a 64 × 64 triangle through EGL 1.5 / OpenGL ES 3.2 using `zink Vulkan 1.3(Turnip Adreno (TM) 618 (MESA_TURNIP))`. Readback contained exactly 1,152 red triangle pixels and 2,944 blue background pixels. All 4,096 pixels passed the colour checks; FNV-1a64 was `a5974c516a3c7525`. The test refuses a non-Zink/non-Adreno renderer. Initial screen-selection warnings from the unpatched driver did not prevent the separate surfaceless rendering proof.

The first on-screen attempts exposed three downstream compatibility requirements:

1. **Repeated DRM formats.** All eight SDE planes advertised duplicate FourCC values. Plane 55 repeated ABGR8888, XBGR8888 and NV12; seven other planes repeated ABGR8888. Stock Weston 14.0.2 asserted while importing that list. The tracked Weston patch merges repeated formats and modifiers at the DRM backend boundary, retaining the global assertions. It handles both IN_FORMATS and legacy lists.
2. **Separate GPU and display identities.** KGSL Turnip has no DRM render-node identity matching the SDE device. Stock Zink's DRM screen selection failed and GBM fell through to an unsuitable loader path. An opt-in Zink patch (`P613_ZINK_KGSL_SDE=1`) accepts a sole integrated GPU only when vendor `0x5143`, device `0x06010800` and driver ID `MESA_TURNIP` match, with no DRM render identity. It retains the SDE fd for PRIME/KMS handle import. It does not advertise a fake DRM device or permit CPU fallback. The GBM probe then passed DMA-BUF export, a valid KMS handle, EGL swap and front-buffer lock.
3. **Samsung splash ownership.** The vendor kernel initially reserved plane 55 on CRTC 100 for its splash, while Weston chose CRTC 137. Atomic commits failed with the kernel's `used in cont-splash on crtc:100` error. A brief invocation of the already-tested legacy display tool, followed by disabling its CRTC, released that reservation. Weston could then present normally. The launcher automates this handoff once per native boot.

The runtime also needs XKB keyboard-layout data even with input testing disabled. Those files are copied into the RAM overlay. Libseat's builtin seat manager runs with `SEATD_VTBOUND=0`; this kernel has no VT subsystem. No systemd session or Android filesystem is needed for this experiment. See [Weston's documented standalone/libseat setup](https://wayland.pages.freedesktop.org/weston/toc/running-weston.html).

**The user confirmed the coloured triangle rotating on the tablet, then confirmed continuous rotation during the automated repeat.** Weston used its GL renderer on Zink/Turnip and enabled DSI-1 at 1200 × 2000 / 60 Hz with atomic modesetting. The virtual output was disabled. The bounded test session finished after 120 seconds with exit zero. This establishes the graphics proof required by step 8; it is not a Hyprland, Arch or Omarchy installation.

### Rebuild the successful graphics stack

```sh
docker build -t omarchy-p613-graphics:debian13 -f buildenv/graphics.Dockerfile .
bash scripts/build-graphics-probes.sh
bash scripts/build-gpu-probes.sh
bash scripts/build-zink.sh configure
bash scripts/build-zink.sh build
bash scripts/build-zink-display-bridge.sh

docker build -t omarchy-p613-weston:debian13 -f buildenv/weston.Dockerfile .
python3 scripts/prepare-weston.py /Volumes/OmarchyBuild
bash scripts/build-weston.sh configure
bash scripts/build-weston.sh build
bash scripts/build-wayland-runtime.sh bridge final
```

The Mesa canonical source stays pristine. The display-bridge builder copies the baseline build cache to a separate SSD output and overlays one checksum-verified patched source file read-only in the container. Upstream/patched source and patch hashes are pinned in `mesa.lock.json`, `mesa-display.lock.json` and `weston.lock.json`. Weston has a separate patched checkout. Runtime assembly refuses to overwrite an existing named bundle; choose a new final bundle name when rebuilding it. Debian package versions are recorded, but package repositories are not frozen to a snapshot, so this does not promise byte-identical future binaries.

Transfer the final RAM overlay and the privately captured firmware using the existing pinned-key SSH process, checking the generated manifest on the device before execution. Run the offscreen and GBM probes before the compositor. The on-device compositor command is:

```sh
/gpu/bin/run-wayland-test.sh --show-120-seconds
```

The launcher runs for at most two minutes after startup, stops its client/compositor and logs to RAM. The tested invocation additionally used BusyBox `timeout -s TERM -k 10 160` and captured the exit status separately. It requests the GL renderer explicitly; no Pixman fallback or software GPU driver is part of this bundle. Firmware, private keys, BOOT images and complete raw device logs remain excluded from Git.

### Limits to carry into step 9

- Weston logged an abnormal initial repaint-delay timestamp; presentation-clock behavior needs investigation before performance or suspend claims. The user still observed continuous animation.
- Normal shutdown could report a pending flip while destroying the output; cleanup completed. This is not a clean long-duration stability certification.
- No input devices were configured in the minimal runtime. Touch/S Pen interaction and all other tablet hardware remain unvalidated.
- The Zink identity bridge is a scoped SM-P613 bring-up patch, not an upstream general solution for multiple GPUs.
- Kernel 4.14 compatibility with current Arch Linux ARM packages, systemd and Hyprland remains a separate gate. Neither Hyprland nor Omarchy has run yet.

After test 04, the exact original BOOT was restored. Android boot completion, unlocked state and all four original partition hashes were verified. No native test remains running. Sanitized hardware evidence: `build-records/hardware-test-04.json`; exact build/runtime evidence: `build-records/wayland-build.json`.
