# Omarchy shell on SM-P613

Step 9 now has the real Omarchy 4.5 host, mobile home, app drawer, status bar, recents and back gesture on native Arch Linux ARM. This is a UI subset: the complete Omarchy package, its installer and its systemd service graph are not installed. BusyBox remains PID 1. The existing 4.14 kernel cannot support current systemd's declared minimum.

## Image and launch architecture

The proven Arch RAM image is retained. A separate ext4 preparation clone supplies the new read-only SquashFS image. It includes signature-checked Arch Qt/dependency packages, hash-pinned Omarchy/Quickshell/settings runtime payloads and the pinned upstream mobile bar. Detached Omarchy signatures are checked against the pinned, HTTPS-bootstrapped keyring fingerprint; this bootstrap is not an independent verification of the key owner's identity. Device firmware and generated images remain private.

`/opt/p613-compat/lib/libudev.so.1` is the hash-verified 257 library from the working Weston runtime. It is selected only for this experiment through LD_LIBRARY_PATH; installed Arch libudev is unchanged. The working Zink/Turnip KGSL/SDE stack remains under `/opt/p613-gpu`. The desktop runs as UID 1000 through seatd and a private D-Bus session, with RAM home, tmp and run directories. Android filesystems are not mounted.

The UI profile loads the mobile bar, home, launcher, switcher and back gesture, with screensaver/lock disabled. Network/Bluetooth/UPower services are not started; a disconnected icon is expected and does not establish Wi-Fi support. Touch and pen are classified in the RAM udev database; missing pen resolution is supplied from verified ranges and panel dimensions. Response and pressure were confirmed; edge accuracy, palm rejection and rotation are unvalidated.

## Qt fallback initialization

Initial startup became unresponsive or left completed helpers unreaped, preventing plugin discovery. A basic Quickshell process/timer probe worked. A temporary diagnostic sigaction interposer observed Qt's SIGCHLD handler installation in a child PID, while the parent had no such handler. GDB located a blocking forkfd status-pipe read. The diagnostic library is not part of the image.

Qt 6.12's [detached-process implementation](https://github.com/qt/qtbase/blob/v6.12.0/src/corelib/io/qprocess_unix.cpp) can use vfork before calling startChild. On this kernel, [forkfd](https://github.com/qt/qtbase/blob/v6.12.0/src/3rdparty/forkfd/forkfd.c) uses its signal/pipe fallback. Our observed behavior is consistent with fallback initialization in the shared-memory child updating the parent's initialization state without installing its signal handler in the parent.

`configs/p613-shell-bootstrap.qml` runs `/usr/bin/true` as a normal managed Process and waits for its exit before loading the real host. In the hardware trial, this restored child reaping, responsive IPC and the active mobile bar. The upstream host is preserved byte-for-byte as `p613-upstream-shell.qml`; the bootstrap occupies the normal `shell.qml` entry point to preserve IPC configuration paths. Omarchy's loader pragma is retained for its packaged Qt compatibility handling. No Qt library or kernel is patched for this workaround.

## Reproduce

With configured SSD storage mounted and the ARM64 RAM-root builder available:

```sh
python3 scripts/fetch-omarchy-shell-inputs.py
bash scripts/build-mesa-fd-fix.sh
bash scripts/build-omarchy-root.sh prepare
```

`prepare` refuses an existing developer image. `resume` continues a preparation only when no final `root.squashfs` exists; retain each earlier compressed image and its validation record before rebuilding. No physical block device is supplied to the container. The build checks package signatures, library resolution, Quickshell version, Hyprland configuration and the compressed size budget. Arch repositories are updated during the build; future package versions and image hashes may differ. The tested package inventory is recorded in build-records/omarchy-package-versions.txt. A config-only IPC warning is expected outside a compositor and is not a hardware pass.

On the already booted, matching RAM kernel, `scripts/stage-arch-ram-test.py --profile omarchy` checks BOOT, root and firmware hashes before staging. It does not flash or start graphics. The native launcher accepts the original bounded `--show-120-seconds` mode or `--show-extended-test` with P613_TEST_SECONDS between 300 and 3600. Set P613_USE_UDEV_COMPAT=1, P613_ENABLE_INPUT=1, P613_EXPECT_OMARCHY=1, P613_EXPECT_MOBILE=1 and P613_HYPRLAND_CONFIG=/etc/p613/hyprland-omarchy.lua. The launcher defaults to Qt basic rendering; P613_QSG_RENDER_LOOP=threaded remains available for comparison. The launcher cleans up the test user's processes at exit while retaining root recovery SSH.

The owner authorizes leaving native Linux testing mode active between experiments. Android restoration remains available through the exact BOOT backup and is no longer required after every test. RAM session changes disappear on reboot; the development scripts and evidence are committed and pushed.


## Verified hardware checkpoint

The final revision-3 image passed a clean 120-second session with zero exit status. Every 15 seconds the worker required a successful IPC ping and an active omamobile.bar plugin. Screenshots were inspected and the user confirmed the visible status bar. Non-root Zink/Turnip readback passed again. BOOT matched the test candidate; recovery, DTBO and vbmeta remained unchanged. A longer desktop session was then started for continued testing, not counted as a completed stability test. See build-records/hardware-test-07.json.


## Mobile interaction and resource fixes

The runtime now includes the pinned mobile plugin sources and helpers. A scoped launch patch uses GIO directly in the manual session. The switcher's P613 profile uses static app cards: its live capture path raced disappearing windows and disconnected the shell when an app closed. The driver also needed explicit closes of allocation DMA-BUF fds after imports duplicated them. Before/after hardware testing found +64 versus zero leaked descriptors in 64 allocation cycles; ten app lifecycle cycles then passed with fixed Turnip and static cards. This does not establish long-duration stability. See input-bringup.md and build-records/mesa-fd-fix-build.json. Live recents previews are not part of the validated profile.
