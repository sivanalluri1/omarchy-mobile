# Progress

Status: step 9 in progress. First native Arch read-only SSD-root connection and commands passed. A subsequent NBD connection/mount attempt lost USB/SSH responsiveness; Android is restored and all four original hashes verified. Step 8 graphics proof remains valid.

- [x] Read-only SM-P613 hardware audit.
- [x] Pin and fetch the exact running kernel source.
- [x] Review Samsung restrictions and ROM installation/upgrade history.
- [x] Inspect matching recovery/vbmeta release archive offline.
- [x] Create plan, architecture and development steps.
- [x] 1. Validate local ARM64 Linux kernel builder.
- [x] 2. Generate and compare unchanged vendor configuration.
- [x] 3. Compile and inspect unchanged kernel/device-tree outputs.
- [x] 4. Verify installed recovery, Download Mode status and restoration set.
- [x] 5. Build minimal Linux configuration/initramfs with NCM and SSH.
- [x] 6. Validate candidate image packaging and review BOOT-only rollback.
- [x] 7. Prove native boot and USB/SSH on hardware; restore Android afterward.
- [x] 8. Prove display and accelerated Wayland.
- [ ] 9. Integrate Arch Linux ARM and Omarchy.
- [ ] 10. Validate remaining tablet hardware.

## Current work

Step 1 passed: ARM64 Debian container built; clang/LLD 19.1.7, native executable and AArch64 object compilation verified. Evidence: docs/build-records/builder-validation.txt.

Step 2 passed: generated vendor configuration has zero symbol-value differences against the running tablet config. Evidence: docs/build-records/vendor-config-comparison.json.

The macOS checkout has case-colliding filenames. A fresh checkout from its Git objects is clean in Docker Linux storage; builds use that read-only source and case-sensitive output volumes. Earlier source-cleanliness claims applied insufficient validation and are superseded by this Linux checkout check.

Step 3 passed: unchanged source compiled with LLVM 19.1.7 and external DTC 1.7.2. Image header, AArch64 ELF, both device-tree blobs and source cleanliness verified. The 52,684,824-byte Image and artifact hashes are recorded in docs/build-records/kernel-baseline-artifacts.json.

Step 4 in progress: matching LineageOS ROM ZIP and recovery TAR downloaded and digest-verified. Boot/DTBO/recovery inventory recorded. User reports internal storage is backed up. Physical USB ADB verified. Exact installed boot/recovery/DTBO/vbmeta backed up and device hashes verified using existing Magisk root. Installed recovery identifies 23.2-20260820. Rebooted to Download Mode for transport checks; initial USB enumeration was delayed, then detection and a 90-entry PIT read succeeded. Physical exit and Android/ADB return verified. Named screen fields were not visible. Matching factory firmware downloaded; archive SHA256 recorded and all ZIP members passed CRC checks. Nested TAR.MD5 validation and final restoration review remain pending. See docs/recovery-preparation.md. No flashing has been performed; one deliberate Download Mode reboot was issued.

## Build compatibility notes

- Native ARM64 LLVM 19 differs from the installed ROM's Android LLVM 21; no byte-identical reproduction is claimed.
- The bundled DTC failed parsing the Samsung overlay. Using the supported DTC_EXT=/usr/bin/dtc override succeeded without source edits.
- CONFIG_BPFILTER is disabled in the baseline; the build's bpfilter linker-probe warning did not omit an enabled feature.
- About 40 GiB internal space remained after compilation and downloading the restoration ROM. External SSD is not yet required; request it before larger parallel baselines or approaching the 20 GiB threshold.

### Step 4 checklist

- [x] Physical USB ADB verified.
- [x] User confirms internal storage backup.
- [x] Exact installed boot/recovery/DTBO/vbmeta captured and hash-verified.
- [x] Installed recovery release and vbmeta flags inspected.
- [x] Available Download Mode observations recorded; named OEM/KG/FRP/SWREV fields not exposed.
- [x] Working Download Mode USB session and PIT read verified.
- [x] Return to Android verified.
- [x] Restoration inputs and BOOT-only rollback mapping reviewed; factory archive and all four nested TAR.MD5 payloads verified. Actual restore writes remain untested.

## Previous pause checkpoint (resumed)

Tablet returned to Android; USB ADB verified, sys.boot_completed=1 and flash.locked=0. No flashing or erase performed. Exact boot-chain backups, matching LineageOS release and factory firmware archive are local under ignored work/. Installed boot kernel/DTB match the ROM ZIP; ramdisk differs. Step 4 remains open for nested factory-package validation and final restoration review. Resume after the user attaches the SSD and supplies its volume name. No build/download process remains running.

## Resumed on SSD

SSD storage configured under /Volumes/siva_ssd/Development/Omarchy. A case-sensitive APFS sparsebundle mounts at /Volumes/OmarchyBuild. Source cleanliness and baseline hashes match after migration; work/ is now an SSD symlink after checksum comparison. Original internal work copy and Docker volumes remain intact as fallbacks.

Step 4 complete for offline development readiness: exact installed images, recovery identity, Download Mode PIT/read-only transport and return to Android verified; matching factory ZIP and four nested TAR.MD5 payloads checked. Named OEM/KG/FRP/SWREV text was not exposed and a restore write has not been tested. Those limits remain part of the later hardware test review.

Step 5 in progress: minimal Linux kernel configuration and a RAM-only USB NCM / key-only SSH initramfs. No flashing or device reboot in this resumed session.

## Step 5 completed

Minimal kernel compiled successfully from clean pinned sources on SSD; Image/ELF/device-tree/config hashes inspected. Only DEVTMPFS, DEVTMPFS_MOUNT and FHANDLE differ from the running vendor config. RAM-only initramfs built; native ARM64 BusyBox, chroot shell and real key-only SSH remote command passed in an isolated container. Archive ownership/modes/device nodes inspected and client private key excluded. USB NCM/DHCP and tablet boot remain untested. Source: docs/minimal-linux.md; evidence: docs/build-records/kernel-minimal-artifacts.json and initramfs-validation.json.

Next: step 6, inspect the BOOT-only candidate and review its exact hardware-test/rollback scope. No image has been flashed.

## Step 6 completed — hardware gate

BOOT-only candidate generated at 96 MiB and inspected. AOSP tools verified its AVB footer/hash; embedded kernel, initramfs and installed DTB match validated inputs. Load addresses, OS compatibility fields and command line are preserved. Current unsigned algorithm NONE / flags 3 retained. Exact candidate/rollback hashes and proposed commands are in docs/boot-experiment.md. No flash or native boot has occurred. Step 7 requires explicit authorization for the first BOOT-only test and restoration of Android afterward.

## Step 7 completed — real hardware

User authorized the first BOOT-only test and restoration. Candidate flashed and booted native Linux; on-device BOOT hash matched the candidate. USB NCM, DHCP and pinned-key SSH worked. PID 1 was the RAM-only /init and no Android filesystem was mounted. Recovery/DTBO/vbmeta remained unchanged. Re-entered Download Mode over native SSH, restored the exact original BOOT, and verified Android boot completion, USB ADB and all four original partition hashes. See docs/hardware-test-01.md and docs/build-records/hardware-test-01.json.

Step 8 remains incomplete: DRM/KGSL nodes and a connected DSI connector were observed, but no visible display or GPU acceleration test has run. Tablet is currently back in its original rooted LineageOS installation. No further flash is running.


## Step 8 — display milestone

- [x] Build static ARM64 DRM/KGSL enumeration and bounded display tools.
- [x] Query real display modes and Adreno device information under native Linux.
- [x] Display CPU-rendered colour bars at 1200 × 2000, 60 Hz; user confirmed visible output.
- [x] Prove GPU rendering through Turnip/KGSL without software fallback.
- [x] Prove GPU/display buffer sharing and accelerated Wayland.

The known-good BOOT candidate was reused. Firmware was copied from Android into the native RAM rootfs; no Android filesystem was mounted. DSI modesetting succeeded; KGSL device query succeeded. Evidence and source/build commands: docs/graphics-bringup.md and docs/build-records/hardware-test-02.json. Full step 8 is not yet complete.

After test 02, the exact original BOOT was restored. Android boot completion and unlocked state were verified; BOOT/recovery/DTBO/vbmeta all match their preflight hashes. No hardware test remains running.

### Step 8 — Turnip build

- [x] Build pinned Mesa Turnip with the KGSL backend for AArch64.
- [x] Build bounded GPU compute dispatch/readback probe and Turnip-only runtime.
- [x] Verify no-device container test fails instead of selecting a software driver.

Hardware shader execution remains pending at this checkpoint. See docs/build-records/turnip-build.json.


### Step 8 — hardware compute passed

- [x] Run a real Vulkan compute shader on Adreno 618 through Turnip/KGSL.
- [x] Verify all 1,024 GPU-produced values and zero exit status, with Turnip as the only ICD.
- [x] Restore original Android BOOT and verify boot completion and all four original partition hashes after test 03.

Hardware reports Turnip Adreno (TM) 618, Vulkan 1.3.354. This proves GPU shader execution, but graphics rasterization, GPU/display buffer sharing and accelerated Wayland remain open. Next: Zink/EGL rendering. Evidence: docs/build-records/hardware-test-03.json.


## Step 8 completed — accelerated Wayland on hardware

- [x] Render and verify every pixel of a GPU triangle through Zink/Turnip (1,152 red + 2,944 blue).
- [x] Diagnose and patch repeated downstream DRM plane formats in Weston.
- [x] Add an opt-in, hardware-restricted Zink bridge for separate KGSL/SDE identities.
- [x] Verify GBM DMA-BUF export, valid scanout handles, EGL swap and front-buffer lock.
- [x] Release Samsung's initial splash-plane reservation using the validated legacy modeset path.
- [x] Run Weston GL on DSI-1 at 1200 × 2000 / 60 Hz with a Wayland EGL client.
- [x] User confirms rotation, then continuous rotation during the automated repeat.
- [x] Complete both bounded two-minute sessions with zero exit status, including automated splash handoff.
- [x] Verify all 405 final runtime files by hash on the native tablet.

Evidence: docs/graphics-bringup.md, docs/build-records/wayland-build.json and hardware-test-04.json. No Android filesystem was mounted. Initial repaint-clock warnings and a pending-flip shutdown message remain documented; no performance or long-duration stability claim is made. Input remains unconfigured in this minimal runtime. Hyprland/Arch/Omarchy have not run; step 9 must begin by checking userspace compatibility with kernel 4.14.

After hardware test 04, the original BOOT was restored. Android boot completion and unlocked state were verified, and all four partition hashes match the original backups. No compositor or flash remains running. Step 8 is committed as complete; step 9 has not started.

## Step 9 started — Arch compatibility and root image

- [x] Inspect current Arch Linux ARM and pinned Omarchy Mobile sources.
- [x] Confirm Arch glibc's declared minimum (3.7) and systemd's incompatible supported minimum (5.10).
- [x] Build a metadata-correct SSD-backed ext4 root image; disable ext4 features too new for 4.14.
- [x] Upgrade/install signature-checked Arch packages, including Hyprland 0.57.2 and Aquamarine 0.16.0.
- [x] Verify Arch commands and package inventory inside the ARM64 build container.
- [x] Build/inspect NBD-enabled kernel and independently packaged BOOT candidate.
- [x] Prove initial read-only USB/SSD root access and Arch commands on the tablet.
- [x] Prove non-root Hyprland with the working KGSL/SDE Mesa stack.
- [ ] Integrate portable Omarchy Mobile components and resolve unsupported services.

Current systemd 262.2 does not support this 4.14 kernel. BusyBox remains PID 1 during userspace testing; no full supported Arch/systemd/Omarchy boot is claimed. Details: docs/arch-userspace.md; initial evidence: docs/build-records/arch-bootstrap.json. No step 9 BOOT image has been flashed at this checkpoint.

Step 9 offline checkpoint: NBD-only config delta verified; new BOOT candidate structurally validated and previous candidate retained. Arch filesystem/NBD-server checks and non-root Hyprland config validation passed. The hardware test remains pending. Evidence: docs/build-records/arch-offline-validation.json.


### Step 9 hardware test 05 — partial success, recovery pending

The NBD-enabled BOOT booted and matched its readback hash. The initial read-only NBD/ext4 mount worked; native Arch glibc 2.43, bash, pacman queries and UID 1000 user were verified. The first graphics probe exited for a missing Vulkan loader. That signed package was added offline after unmounting/stopping the export. The subsequent NBD connection/mount attempt in the same boot lost USB/SSH responsiveness before another GPU probe started. Root cause is unknown. The mount helper now refuses a second connection per boot as containment, not as a proven fix.

Android filesystems were not mounted. Original BOOT has NOT yet been restored after test 05: physical Download Mode is required, and the user has been given the button sequence. Keep step 9 open. Evidence: docs/build-records/hardware-test-05.json. Next recovery work: restore original BOOT, verify Android and all four original hashes, and inspect pstore/last-kernel logs privately before further hardware experiments.

Test 05 recovery completed: user entered Download Mode; original BOOT restored, Android boot completion/unlocked state and all four original partition hashes verified. One pstore console was saved privately but is corrupted/incomplete and does not establish the stall cause. The NBD export is stopped. Next approach: prepare a compressed RAM-only Arch root while Android stays running; retain NBD evidence as an incomplete transport experiment.


### Step 9 — RAM-root offline checkpoint

- [x] Preserve the original NBD image and build a separate compressed RAM root.
- [x] Trim generic firmware/cache; include privately captured, hash-verified tablet GPU firmware.
- [x] Build the 328 MiB SquashFS/XZ image and pass read-only loop/chroot, non-root PTY/config and library checks.
- [x] Build and structurally validate a separate SquashFS kernel/BOOT candidate with NBD disabled.
- [x] Run the RAM-root Arch/Hyprland test on the tablet.

Android is currently restored and verified. The old NBD stall remains undiagnosed; it is removed from the new experiment path. Current systemd remains unsupported on kernel 4.14. Evidence: docs/build-records/arch-ram-offline-validation.json.


### Step 9 — native Arch and Hyprland hardware checkpoint (2026-11-15)

- [x] Verify reconnected SSD volumes and critical image hashes.
- [x] Boot the SquashFS-enabled kernel with NBD disabled; mount verified Arch root entirely in RAM.
- [x] Pass non-root Zink/Turnip GPU readback: 1,152 red pixels, 2,944 blue pixels.
- [x] Diagnose DRM enumeration: Arch libudev 262 returns -49; isolated libudev 257 enumerates card0 as root and UID 1000.
- [x] Run Hyprland 0.57.2 as UID 1000 for 120 seconds with a mapped foot terminal; wrapper exits zero.
- [x] Restore Android; verify boot completion, unlocked state and all four original partition hashes.
- [ ] Integrate Omarchy components and resolve unsupported services.

User confirmed the Hyprland terminal and updating clock were visible during the bounded session. Touch, pen and long-duration stability remain unvalidated. BusyBox remains PID 1; systemd 262 requires kernel >=5.10 and is unsupported on this 4.14 kernel. Step 9 remains open. Evidence: docs/build-records/hardware-test-06.json. Next: make the compatibility prefix reproducible in the RAM image, then inspect portable Omarchy shell dependencies before another bounded hardware test.


### Step 9 — Omarchy shell image prepared

- [x] Pin Omarchy 4.5.0-3 and its Quickshell runtime; verify detached signatures against the pinned HTTPS-bootstrapped keyring.
- [x] Preserve the proven Arch image; build a separate 582 MiB RAM image with the compatibility libudev prefix.
- [x] Include the real Omarchy shell host, mobile bar and an isolated profile with idle/lock disabled.
- [x] Check Quickshell libraries/version and Hyprland profile offline.
- [x] Validate Omarchy host and mobile bar on the native tablet.

User authorizes keeping the tablet in native Linux testing mode between tests; routine Android restoration is no longer required. Original recovery images remain retained. Systemd, input and hardware services remain unresolved. This image extracts runtime payloads without installing the full Omarchy package or running its installer/hooks. Evidence: docs/build-records/omarchy-root-build.json.

Omarchy image revision 2 adds the matching signature-verified settings data, helper scripts, inotify-tools and Python D-Bus/GObject dependencies (584 MiB). Revision 1 had an unresponsive startup; adding settings/helpers in RAM restored IPC, but plugin discovery still did not finish and helper children remained unreaped. Small valid/missing-command Quickshell probes continued ticking. No root cause is established yet; revision 2 hardware testing is in progress. Both previous compressed images are retained privately.


### Step 9 — real Omarchy shell/mobile bar passed (2026-11-15)

- [x] Include matching Omarchy/settings/Quickshell runtime payloads and a private libudev compatibility prefix.
- [x] Trace the Qt startup failure; prime its old-kernel forkfd fallback in the parent before loading the real host.
- [x] Build revision 3 (584 MiB), preserving the unmodified upstream host under a new filename.
- [x] Stage a clean read-only RAM mount without diagnostic overlays or preload libraries.
- [x] Pass the 120-second session with zero exit status and periodic shell IPC/active-bar checks.
- [x] Inspect screenshots; user confirms the clock/status bar is visible above the terminal.
- [x] Repeat non-root hardware GPU readback on the final image.
- [x] Verify native BOOT readback and unchanged recovery/DTBO/vbmeta hashes.
- [x] Leave an extended desktop session in native Linux testing mode, as authorized.
- [x] Add the mobile home/app drawer.
- [ ] Finish service compatibility work.
- [ ] Validate touch/S Pen and remaining hardware functions individually.

The extended session has started, not completed; no hour-long stability claim is made. The completed result is the bounded two-minute test. Android is not restored after this test, per the owner's updated instruction. BusyBox remains PID 1; current systemd is unsupported on 4.14. Step 9 remains in progress. Evidence and reproduction: docs/omarchy-shell.md and docs/build-records/hardware-test-07.json.


### Steps 9/10 — mobile home and real input checkpoint (2026-11-15)

- [x] Render the upstream mobile home and launcher from a RAM overlay.
- [x] Classify touchscreen/pen/key devices in the RAM udev database.
- [x] Supply missing pen resolution using panel dimensions and verified ranges.
- [x] Enumerate touch and tablet devices in libinput and Hyprland.
- [x] Capture actual touch, pen tip/proximity/motion and variable pressure; owner confirms both inputs respond.
- [ ] Verify desktop-entry app launch and complete a stable interactive repeat.
- [ ] Validate edge accuracy, palm rejection, rotation and remaining hardware.

The interactive desktop stalled in SquashFS reads under low available memory after a missed IPC response. Native recovery SSH remained available. Evidence is saved before reboot; root cause is not established. This is a partial milestone, not completion of step 9 or step 10. Details: docs/input-bringup.md and docs/build-records/hardware-test-08.json.


### Step 9/10 — lifecycle failures reproduced and fixed in test runtime

- [x] Pass a clean revision-4 home/launcher session and launch Foot via GIO.
- [x] Reproduce recents closing failure: a live toplevel capture races a disappearing app.
- [x] Add static recents app cards to the P613 profile while retaining switch/close behavior.
- [x] Identify Turnip's missing closes of allocation DMA-BUF descriptors.
- [x] Verify the driver fix on hardware: 64 allocation cycles changed from +64 leaked fds to zero.
- [x] Repeat GPU readback with the repaired library.
- [x] Complete ten actual Foot open/close cycles with recents visible, shell IPC and home-state checks.
- [x] Validate the combined fixes in a newly built immutable image.

The ten-cycle result used verified RAM overlays; the new image is building. Both the original display driver and earlier root images remain preserved. Full systemd service integration, OSK and remaining hardware work are open. Step 10 input response/pressure is confirmed, but accuracy, palm rejection and rotation are not yet validated.


### Steps 9/10 — final mobile profile checkpoint (2026-11-15)

- [x] Build revision 5 with complete plugin sources, GIO launch adaptation, static recents and repaired Turnip.
- [x] Verify the image hash and mount it cleanly without runtime overlays.
- [x] Pass the 120-second shell/home/launcher session with periodic IPC checks and zero exit status.
- [x] Repeat ten actual app open/close cycles with recents visible on the immutable image.
- [x] Pass the 64-allocation descriptor regression and GPU pixel readback from the final image.
- [x] Verify original recovery/DTBO/vbmeta hashes and the expected native BOOT hash.
- [x] Leave a longer native desktop session active, as authorized.
- [x] User confirms the final recents close remains visible and responsive.
- [ ] Complete longer interaction checks.
- [ ] Integrate on-screen keyboard, networking, audio and remaining services/hardware.

Touch/pen response and pen pressure are confirmed. The final workload retained at least 1,548,816 KiB available in the five-second samples; sampled ION heap usage reached 520,108 KiB. These samples are bounded observations, not performance or long-duration guarantees. Current systemd is unsupported on 4.14; BusyBox remains PID 1. Full steps 9 and 10 remain open. Evidence: docs/build-records/hardware-test-08.json and docs/input-bringup.md.


### Paused at owner request — 2026-11-15

Desktop/test-user processes and seatd were stopped, the Arch RAM root was unmounted, filesystems synced, and native power-off requested. The tablet disappeared from the Mac USB inventory afterward. No project containers or host test/flash/staging processes were running. The SSD is being detached/ejected for storage.

Resume from commit ec10d79's validated revision-5 image (SHA256 4d509fa2f13482c0de36d60458957f050ef8cd3796b35f2356fc16a1d515eb07), not an earlier root. The repaired Turnip library SHA256 is c0051c7823d64be174f883b823b0314880a183190fce9a760de06e5d7d550a86. Native BOOT remains installed (e6585dfd5a81025f3848e6a2cee20d4b5914a929b0153758365a4c964a74fbc6); Android was not restored, as authorized. RAM session state is lost at power-off.

When the owner reconnects the tablet and SSD and requests continuation, verify both devices, mount the case-sensitive build sparsebundle, boot/check native Linux and restage the revision-5 RAM image using the pinned-key staging helper. Enable the compatibility/input/mobile checks in the launcher. Next development work remains on-screen keyboard and service/hardware integration. Do not resume automatically while paused.


### Resumed at owner request — 2026-11-15; keyboard image prepared

The reconnected SSD/build volume was verified (filesystem check exit zero), and Download Mode was detected on SM-P613. A read-only PIT session rebooted the existing native image without flashing. Native kernel/BOOT readback matched the validated experiment. Development resumed explicitly after the owner's pause.

- [x] Preserve the tested revision-5 image and prepare a separate keyboard revision.
- [x] Install signature-checked Squeekboard, GTK/GSettings/dconf, wtype and libbsd dependencies.
- [x] Start the keyboard directly in the manual private session bus; enable the mobile keyboard plugin.
- [x] Configure the session's Wayland input-method environment.
- [x] Add offline keyboard-library, GTK import and profile checks, plus a visible typing fixture.
- [x] Verify keyboard visibility, real typing/Enter and show/hide behavior on the tablet.

Revision 6 failed startup because libbsd.so.0 was absent. The dependency was added explicitly and checked before revision 7 was packaged. Keyboard hardware validation remains pending; package installation alone is not a pass. Evidence: docs/build-records/keyboard-offline-validation.json.


### Step 9 — on-screen keyboard hardware checkpoint (2026-11-15)

- [x] Receive the requested text and Enter through the visible native keyboard fixture without synthetic typing.
- [x] Pass four hide/show visibility checks with the mobile plugin watcher active.
- [x] Complete a clean 120-second session with periodic keyboard/mobile checks and exit zero.
- [x] Pass five actual Foot open/close cycles with the keyboard service active.
- [ ] Integrate Wi-Fi, audio and power services; validate remaining input behavior.

Revision 7 is now the latest tested RAM image. Its SHA256 is 4f054089f3f90861911cae89454d70edd69ee2e1189c754acd697b0f9e9a85c1. Stock US keyboard layouts are validated; language/theme integration remains open. The earlier keyboard-pending note records the preparation stage. See docs/build-records/hardware-test-09.json.


### Step 10 — Qualcomm radio prerequisites (2026-11-15)

- [x] Reconstruct the saved LineageOS full vendor image offline and verify two reconstructions match.
- [x] Extract Samsung ADSP/modem firmware and LineageOS Wi-Fi configuration/BDF to private SSD storage.
- [x] Verify all 74 staged firmware file hashes in native RAM.
- [x] Bring ADSP and modem online with legacy QRTR discovery, protection-domain mapper and TFTP support.
- [x] Run RMTFS using RAM snapshots in read-only shadow mode; compare all four snapshots with original partitions afterward.
- [x] Discover WLFW service 69, transfer five BDF segments and receive calibration-report acknowledgement.
- [x] Observe the kernel's WLAN firmware-ready message.
- [x] Create a working WLAN interface and scan.
- [x] Validate network connection and mobile-shell network integration.

The current host probe fails with errno -14 before creating wlan0. An earlier ON request preceded firmware support startup, so a clean ordered startup is the next check. The BDF transfer initially failed on its last segment when total_size decreased per segment; keeping total_size constant succeeded, matching the inspected userspace implementations. Wi-Fi is not yet functional. No flash or original modem-storage write was performed. See docs/build-records/hardware-test-10.json.


### Step 10 — first native Wi-Fi scans (2026-11-15)

- [x] Reproduce the probe failure after a clean startup without IPA.
- [x] Load IPA firmware and initialize its SMMU mappings before Wi-Fi startup.
- [x] Create wlan0 on the unchanged native kernel.
- [x] Assign a temporary locally administered station MAC before scanning.
- [x] Complete three scans with both 2.4 and 5 GHz results (55, 43 and 65 BSS entries).
- [x] Recheck all four original modem-storage partitions against RAM snapshots.
- [x] Verify the consolidated startup helper from a fresh boot.
- [x] Validate authentication, DHCP, packet transfer and mobile network controls.

The prior failure record is retained as experiment history. IPA-first startup resolved the probe failure without a kernel change. The optional wlan_mac.bin lookup caused a 60-second wait; the new RAM-only address generator is intended to avoid that wait and serial-derived fallback. SSIDs, BSSIDs and raw modem data remain private.

The consolidated helper passed a fresh 120-second run, compared original storage with RAM snapshots, exited zero and stopped its support services with the modem OFFLINE. A subsequent supervised startup also succeeded without another reboot. Four temporary locally administered addresses supplied in a RAM-only wlan_mac.bin avoided the optional-file timeout.


### Step 10 — native Wi-Fi connection checkpoint (2026-11-15)

- [x] Enter the network password on the tablet using the native keyboard and a GTK test prompt.
- [x] Authenticate WPA2 personal with CCMP through a temporary wpa_supplicant runtime.
- [x] Acquire and apply an IPv4 DHCP lease without disrupting USB recovery.
- [x] Resolve DNS and retrieve two HTTPS sites with certificate verification enabled.
- [x] Disconnect, reconnect, reacquire DHCP and repeat a verified HTTPS request.
- [x] Remove the GUI request and supplicant configuration files from RAM after authentication.
- [x] Package the connection runtime and integrate shell network controls.
- [ ] Validate roaming, long-running connectivity, suspend/resume, audio and remaining hardware.

The owner supplied the network name privately and entered the password on the tablet. No password, derived key, SSID, BSSID or lease address is committed. Direct wpa_supplicant and BusyBox udhcpc work without systemd. The tested connection tools are temporary RAM additions to revision 7, not yet part of the immutable image. A radio-lifetime watcher retires the temporary supplicant when the bounded radio session ends; its exit-time behavior remains to be observed with an active connection. See docs/build-records/wifi-connection-test.json.


### Paused and powered off at owner request — 2026-11-15

The desktop/test-user processes, supplicant and supervised radio services were stopped. The modem reported OFFLINE. The resolver bind mount and complete Arch RAM root were unmounted, filesystems synced, and native power-off requested. The tablet then disappeared from USB. No project containers were running; stale host SSH sessions from earlier reboots were stopped. The build sparsebundle and SSD are being detached/ejected.

Latest validated milestones: revision-7 keyboard/mobile root, native dual-band Wi-Fi scans, WPA2 authentication, DHCP, verified HTTPS and reconnect (commit 373fe07). Native BOOT remains e6585dfd5a81025f3848e6a2cee20d4b5914a929b0153758365a4c964a74fbc6. Root revision 7 remains 4f054089f3f90861911cae89454d70edd69ee2e1189c754acd697b0f9e9a85c1. No Android restoration or new flash was performed. Credentials/session state are lost at shutdown.

On explicit resume, verify the SSD/tablet, mount the build sparsebundle and boot the installed native image. Restage revision 7 with stage-arch-ram-test.py, then stage the 80-file radio firmware set/tools with stage-radio-test.py and use run-p613-radio-test.sh. Its IPA-first sequence and ephemeral MAC file are validated. Start the mobile desktop with compatibility/input/keyboard checks. The connection prompt/runtime can be staged with stage-wifi-connection-test.py; the password must be entered on the tablet again. Next development remains packaging connection management and integrating shell network controls, followed by audio/power and remaining input/hardware checks. Wait for the owner's reconnect/resume instruction.


### Resumed at owner request — network image prepared (2026-11-16)

SSD/build filesystem verified cleanly. Download Mode detected; a read-only PIT session rebooted the existing native image without flashing. Kernel and BOOT hash matched the validated experiment.

- [x] Preserve revision 7 and build revision 8 with signed Arch NetworkManager, wpa_supplicant and iw.
- [x] Package hash-checked private radio firmware and pinned radio tools into the image.
- [x] Enable the upstream mobile quick-settings panel and add a manually supervised system bus/network service configuration.
- [x] Pass offline libraries, networking CLI and compositor configuration checks.
- [x] Validate NetworkManager and shell Wi-Fi controls on hardware.

The isolated experiment restricts NetworkManager management to wlan0 and uses RAM state. Its temporary policy bypasses polkit because there is no logind session; this is not a production multi-user policy. The original USB recovery network stays outside NetworkManager management.


### Step 10 — packaged networking and mobile controls validated (2026-11-16)

- [x] Package signed Arch network tools plus hash-checked radio firmware/helpers.
- [x] Run a manual system bus, wpa_supplicant and NetworkManager without systemd.
- [x] Restrict management to wlan0 and verify USB recovery remains unmanaged and reachable.
- [x] Correct the mobile panel's selection of unmanaged swlan0 to managed wlan0.
- [x] Enter the password directly through the upstream mobile Wi-Fi sheet.
- [x] Validate final revision 9 without code overlays; restore a saved profile only within tablet RAM.
- [x] Validate DNS, DHCP and certificate-verified HTTPS on the final image.
- [x] Toggle Wi-Fi off/on through the shell and automatically reconnect; repeat HTTPS through the dynamic resolver symlink.
- [x] Pass three actual app open/close cycles with the final network-enabled desktop.
- [x] Recheck the native BOOT hash and original modem-storage snapshots.
- [ ] Continue audio bring-up, power/suspend and remaining input/stability checks.

Revision 9 SHA256: 0f3921bb6064a6d69cd234ef2d775bde236f094ac703a9cb3ffd6038575ddb41. Revision 8 is retained, as are the earlier keyboard images. The final image includes the interface-selection patch, RAM connection-profile mounts and a resolver symlink that follows NetworkManager's atomic file replacements. All saved credentials remain exclusively in tablet RAM and disappear at power-off. Manual service startup and the experimental single-user authorization policy remain limitations. Evidence: docs/build-records/hardware-test-11.json and docs/network-services.md.


### Step 10 — native speaker playback checkpoint (2026-11-16)

- [x] Recover USB networking by reconnecting the tablet cable; native desktop stayed responsive and no reboot was required.
- [x] Enumerate main atoll sound card and DBMDX capture card, PCM endpoints and mixer controls.
- [x] Inspect the tablet's vendor mixer routes and preserve a read-only baseline.
- [x] Play quiet alternating stereo tones at 48 kHz, 16-bit; owner confirms both speakers.
- [x] Restore all eight routing/format controls and verify the PCM closed afterward.
- [ ] Integrate desktop audio services and controls.
- [ ] Validate headphones and microphone capture.

The bounded test left amplifier gain, limiter/boost and calibration controls untouched. Playback exited zero and restored every changed control. Temporary ALSA diagnostic binaries were used with the existing Arch alsa-lib; signed Arch utilities and desktop audio packaging are next. See docs/build-records/hardware-test-12.json.


### Step 10 — built-in microphone capture checkpoint (2026-11-16)

- [x] Apply the vendor main-microphone route and capture 160,000 mono samples at 16 kHz while the owner speaks/counts.
- [x] Observe changing signal levels (peak 11,378; overall RMS 487.52).
- [x] Restore all seven mixer controls and verify the PCM closes.
- [x] Delete raw audio from tablet RAM; transfer only numerical signal statistics.
- [ ] Validate microphone intelligibility/quality and desktop capture integration.
- [ ] Validate wired headphones when hardware is available (owner has none currently).

This validates capture through the main WCD/ADSP route; it does not establish DBMDX voice/wake functionality. Desktop audio packaging is in progress.
