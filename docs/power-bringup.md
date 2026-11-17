# P613 power and suspend bring-up

## Scope

Use the existing native BOOT and RAM root. Headphone testing is deferred at the owner's request. Validate timed wake and actual suspended time before desktop integration; a blank panel is not proof of suspend. Keep charging policy and hardware calibration unchanged.

## Baseline — 2026-11-17

Kernel `4.14.357-openela-perf-g21b136df1533` exposes `freeze mem` and `s2idle [deep]`. BusyBox remains PID 1; logind/systemd suspend services are unavailable. Initial suspend success/failure counters are all zero.

The PM6150 RTC exposes `/dev/rtc0` and RTC alarm ioctls, despite having no `wakealarm` sysfs attribute. Its clock starts near the epoch on this boot. Tests use relative RTC time and do not set the hardware clock. An awake 20-second alarm test received `RTC_AF` after 20.377 seconds. The old disabled alarm was restored.

`native/p613-suspend-test.c` is a static foreground probe for this exact validated kernel. It refuses to replace an enabled alarm, requires deep already selected, checks the wakeup-count handshake, arms a 20-second RTC alarm and measures CLOCK_BOOTTIME minus CLOCK_MONOTONIC elapsed time. Less than ten seconds asleep is a failed deep test. The wakeup-count read has a three-second signal deadline: this vendor kernel ignores O_NONBLOCK for that sysfs read. Exit 3 means active wake sources prevented the handshake; exit 4 means the kernel rejected suspend with EBUSY, exit 1 means another failure, and exit 2 means invalid invocation/environment. This is a development probe, not a desktop power daemon.

The connected USB controller `a600000.ssusb` holds a wake source active. Software gadget unbinding alone did not release it. Both attempts stopped before entering system suspend; suspend counters remained zero. Physical cable disconnection is the next controlled experiment, with automatic RTC wake and gadget restoration. No wake source has been forcibly disabled. An initial boot-time wake reason reports `-1 misconfigured IRQ 354 sm5714-usbpd`; it is not evidence of a failed suspend because no suspend had occurred.

Build with `scripts/build-power-probe.sh` using the existing ARM64 graphics-toolchain container. Copy the resulting static binary to `/tmp/p613-suspend-test` on the native root. `native/run-p613-suspend-test.sh` waits up to fifteen minutes for a discharging state after physical cable removal, settles for ten seconds, and retries only blocked wakeup-count handshakes. It performs at most one actual suspend attempt and keeps its log in RAM when launched with redirected output. Leave the gadget configured for physical-disconnect tests. Run only one worker at a time.

The first physical-disconnect request arrived after an earlier two-minute worker had expired; its zero suspend counters do not establish whether physical cable removal permits suspend. The replacement worker uses the longer window above. Kernel source confirms USB-PD registers IRQF_NO_SUSPEND and enables IRQ wake, explaining the diagnostic message. No IRQ policy change has been made.

## Battery units

In the pinned Samsung kernel, `drivers/battery/common/sec_battery.c` requests `SEC_BATTERY_CURRENT_MA` for `current_now` and `current_avg`, and exposes those values directly. Voltage is multiplied by 1000 for microvolts. Generic desktop software assuming standard microamp current therefore needs normalization. The battery was charging, rising from 1% to 4% during initial inspection; no discharge-drain conclusion is possible from this session.

## Remaining validation

- [x] Verify native image, storage and recovery SSH.
- [x] Inventory suspend modes, wake sources, RTC and battery interfaces.
- [x] Prove RTC alarm delivery while awake.
- [x] Prove timed deep suspend and automatic resume without the USB cable.
- [x] Repeat timed cycles and inspect failure counters/wake reasons (Wi-Fi off).
- [x] Validate panel, touch, S Pen and compositor after resume.
- [x] Validate Wi-Fi reconnection and speaker playback after resume.
- [ ] Validate connected-WLAN suspend and microphone capture after resume.
- [ ] Integrate power-button/display policy and normalized desktop battery reporting.
- [ ] Measure unplugged idle/suspend drain with adequate battery charge.

## First deep-suspend result

The physical-disconnect worker entered `mem` with `[deep]` selected and returned zero. CLOCK_BOOTTIME elapsed 20.773 seconds while CLOCK_MONOTONIC elapsed 0.630 seconds: **20.142 seconds suspended**, independently corroborated by `last_suspend_time` (20.142698118 seconds). Suspend success increased to 1; all failure counters stayed zero. Recovery SSH returned after cable reconnection without a reboot. RTC was armed for +20 seconds; automatic resume matched that interval, but the vendor kernel reported “Resume cause unknown,” so an IRQ-specific RTC wake cause is not proven.

This was the minimal native RAM system, before staging the desktop, radio and audio. The log includes Himax resume attempts against a powered-off touch controller and an SDE mode warning. Desktop/input resume must be validated separately before deciding whether those messages are actionable. The raw private evidence is `work/hardware-test-13/deep-suspend-04.txt`.

## Desktop attempt and bounded retry

Revision 11 started its compositor, mobile shell, OSK and audio nodes after the first minimal resume. Owner reconnected Wi-Fi; HTTPS returned 200. The first desktop suspend request was rejected after 0.030 seconds with EBUSY and `Pending Wakeup Sources: mgmt_txrx tx_cmp`. Success remained 1 and failure increased to 1 (`failed_suspend`, errno -16). No deep sleep occurred. DPMS was restored and Wi-Fi remained connected.

The Wi-Fi panel was still open, and its source enables an active scanner while open. Closing it calls `setScanner(false)`; this is a plausible contributor, not a proven sole cause of the wake activity. The panel was closed through its existing IPC. `native/run-p613-desktop-suspend-test.sh` retries only blocked handshakes (exit 3) and EBUSY (exit 4), up to ten attempts per cycle with two-second spacing. It requests three cycles, restores DPMS, and records shell/compositor/audio/network state. Other failures stop the run. No wake sources are disabled or forcibly released. The replacement test is pending physical cable removal.

### Connected-WLAN retry outcome

Closing the Wi-Fi panel did not resolve the issue. Of ten bounded attempts, nine entered the suspend path and returned EBUSY with zero measured sleep; one stopped at the wakeup-count handshake. Kernel totals became success 1 / fail 10 (including the earlier desktop abort). The repeated reason remained pending `mgmt_txrx tx_cmp` wake sources. This is not a transient scan-only result, and additional identical retries are not justified.

The next isolation run temporarily disables WLAN through NetworkManager, retains desktop and audio services, and restores WLAN afterward. It is explicitly not a connected-WLAN suspend test. No wake-source masking or forced release is used.

### Wi-Fi-off desktop result

All three isolation cycles passed, measuring 20.056, 20.453 and 20.466 seconds asleep. Suspend success increased from 1 to 4, with no new failures (the ten earlier aborts remain in the cumulative fail counter). DPMS returned on, shell IPC responded and speaker/microphone nodes remained present after each cycle. NetworkManager restored WLAN and reconnected; HTTPS returned 200. Three post-resume app lifecycle cycles passed. A 30-second PipeWire speaker test exited zero and deleted its synthetic audio file. The owner confirmed audible tones and responsive input after resume.

The tested worker is preserved as `native/run-p613-desktop-suspend-wifi-off-test.sh`. It is a developer test that deliberately restores Wi-Fi on completion, not a general-purpose suspend service or a secure lock-screen policy. Wake cause is still reported unknown by the vendor kernel. Wi-Fi must currently be disabled during desktop deep sleep; connected-WLAN sleep is not validated.

`native/p613-power-status.py` reads battery state without changing hardware. It guards the validated kernel and converts Samsung current from mA to uA. A live snapshot reported charging, 16%, 3.851 V and 29.5 C. Desktop bar integration is separate from this numerical probe.

## Battery status-bar integration in progress

The P613 mobile-bar patch polls `power-status.py` as the ordinary desktop user every fifteen seconds. The percentage, charging state and full state come from its validated snapshot; UPower remains a fallback. A failed probe clears the P613 snapshot instead of preserving stale telemetry. The image assembly installs the helper and applies the bar patch. A RAM bind overlay is currently under visual validation, and a replacement image is building with revision 11 preserved as `root-v11.squashfs`.

Current RAM overlays to remove before unmounting the Arch root: `/arch/usr/share/omamobile/shell/plugins/omamobile.bar/Bar.qml` and `/arch/usr/local/libexec/p613` (unmount the file first, then the directory). They contain only the battery UI/helper change. The native BOOT remains unchanged.

### Percentage visibility and recovery-link checkpoint

The owner confirmed the new battery icon but no numeric percentage. The cause was the existing P613 shell configuration explicitly setting `showBatteryPercent` to false. It is now true in the source configuration; a replacement image is building. The first battery image (51f212adadc1b3ef0542d09ca41e1da9041552b679df9b5aab5c213a131e775c) is preserved privately as `root-power-hidden-percent.squashfs`, not promoted as the final percentage-enabled image. The ordinary image rebuild updated libffi, inotify-tools and tpm2-tss; final-image runtime checks remain required.

During this work the USB interface remained enumerated with its host address, but ping and SSH stopped responding while the owner could still use the desktop. This resembles the previously observed recovery-network stall and remains unresolved. A cable reconnect was requested; no reboot or Android restore was requested.

## Revision 12 startup and battery validation

A native restart recovered USB networking after restoring the Mac address alone did not. The owner entered Download Mode; a read-only PIT session ended with a normal native reboot, without flashing. Revision 12 was then hash-verified, staged in RAM, and started its desktop, keyboard, audio nodes and normalized battery probe. Three app lifecycle cycles passed. The owner confirmed both Wi-Fi connection and numeric battery percentage. No revision-11 RAM overlays remain after this reboot.

Start the system D-Bus, supplicant and NetworkManager before the desktop: starting Quickshell before the system bus left its Wi-Fi panel unavailable until the desktop restarted. The successful restart used network services first. After owner Wi-Fi connection, USB SSH stopped responding again despite the correct Mac address and route. A Wi-Fi-off UI diagnostic is pending; no further suspend test has been armed yet.

`native/p613-recovery-monitor.sh` records up to 360 read-only USB snapshots at ten-second intervals in native RAM, bounded by an outer timeout. It captures address, link/counter and controller-runtime state to aid this unresolved recovery problem. It does not reset the USB controller or alter networking. A power-key test with a 90-second RTC fallback is prepared but has not run.
