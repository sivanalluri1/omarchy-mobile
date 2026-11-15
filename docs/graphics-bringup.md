# Graphics bring-up — SM-P613

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

## Next graphics gate

The vendor kernel exposes separate SDE DRM and KGSL GPU interfaces. A DRM render node alone does not establish compatibility with a normal upstream Mesa/MSM driver.

Mesa's upstream `freedreno-kmds` option explicitly states that Gallium Freedreno does not support KGSL and recommends Zink with Turnip for that interface. The inspected upstream snapshot is `8899a7b4cf1e8b5dbce884f94b440e40e84ca26b`, version 26.2.0-devel. Its Turnip KGSL backend contains both DMA-heap and ION allocation paths. These are source observations, not a successful build or a claim that this exact kernel supports every required operation.

Primary source: [Mesa meson.options at inspected revision](https://chromium.googlesource.com/external/gitlab.freedesktop.org/mesa/mesa/+/8899a7b4cf1e8b5dbce884f94b440e40e84ca26b/meson.options), [Turnip KGSL backend](https://chromium.googlesource.com/external/gitlab.freedesktop.org/mesa/mesa/+/8899a7b4cf1e8b5dbce884f94b440e40e84ca26b/src/freedreno/vulkan/tu_knl_kgsl.cc).

Remaining work:

- Build a pinned Mesa Turnip configuration with the KGSL backend.
- Prove hardware Vulkan rendering with a verified image/readback, excluding software fallback.
- Test DMA-BUF sharing and display scanout compatibility.
- Run an accelerated Wayland compositor; then evaluate Zink/Hyprland and Arch userspace compatibility with kernel 4.14.

Step 8 remains open until acceleration and Wayland have actually run. Raw test logs are private under ignored `work/hardware-test-02`.
