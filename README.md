# omarchy-mobile

Experimental native Linux and Omarchy bring-up for the Samsung Galaxy Tab S6 Lite 2022 Wi-Fi (SM-P613 / gta4xlveu).

Current milestone: revision 13 runs native Arch, accelerated Hyprland and Omarchy's mobile home, launcher, bar, recents and on-screen keyboard on SM-P613. Touch/S Pen response, built-in audio and battery percentage are verified. Power controls now toggle the display over USB and enter untimed deep sleep when unplugged; Power wakes the desktop. The tested sleep path temporarily disables Wi-Fi, serializes power callbacks and restores their prior settings afterward. Packaged startup/cleanup and post-resume app checks passed.

Connected-WLAN sleep, intermittent USB recovery failures, secure locking, idle/low-battery policy, headphone/jack checks, microphone-after-resume quality and longer drain/stability remain open. BusyBox remains PID 1; current systemd does not support kernel 4.14. This is still a RAM-root development prototype.

- [Plan](PLAN.md) · [Architecture](ARCHITECTURE.md) · [Steps](STEPS.md) · [Progress](PROGRESS.md)
- [Omarchy shell integration](docs/omarchy-shell.md)
- [Touch, S Pen and app lifecycle results](docs/input-bringup.md)
- [Desktop audio results](docs/audio-bringup.md)
- [Power, battery and suspend results](docs/power-bringup.md)
- [Network services and controls](docs/network-services.md)
- [Graphics and accelerated Wayland results](docs/graphics-bringup.md)
- [Successful native boot test](docs/hardware-test-01.md)
- [First boot experiment and rollback review](docs/boot-experiment.md)
- [SSD storage](docs/storage.md)
- [Hardware baseline](docs/hardware-baseline.md)
- [Bring-up plan](docs/bringup-plan.md)
- [Samsung boot-chain and ROM research](docs/samsung-boot-research.md)
- [Recovery artifact inspection](docs/recovery-artifact-inspection.json)

Run the read-only audit from a private working directory with an authorized SM-P613 connected:

```sh
bash /path/to/Omarchy/scripts/audit-p613.sh
```

Raw device logs, identifiers, firmware, ROM files and build outputs are excluded from version control. Commit and push completed, verified milestones. Never claim hardware support based only on a successful compilation.
