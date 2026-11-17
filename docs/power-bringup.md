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
- [ ] Repeat timed cycles and inspect failure counters/wake reasons.
- [ ] Validate panel, touch, S Pen and compositor after resume.
- [ ] Validate Wi-Fi reconnection and audio after resume.
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
