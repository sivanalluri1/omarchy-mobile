# omarchy-mobile

Experimental native Linux and Omarchy bring-up for the Samsung Galaxy Tab S6 Lite 2022 Wi-Fi (SM-P613 / gta4xlveu).

Current milestone: revision 11 runs native Arch, accelerated Hyprland and Omarchy's mobile home, app drawer, status bar and recents on SM-P613. Touch/S Pen response, the on-screen keyboard and mobile Wi-Fi controls are verified. Built-in speakers and main-microphone capture work through the ALSA/PipeWire profile; desktop volume/mute and PulseAudio-compatible playback are tested. The final image passed a two-minute combined session and three app lifecycle cycles. Headphone/jack switching, microphone quality, power/suspend and longer stability checks remain open. Current systemd is unsupported on kernel 4.14; BusyBox remains PID 1.

- [Plan](PLAN.md) · [Architecture](ARCHITECTURE.md) · [Steps](STEPS.md) · [Progress](PROGRESS.md)
- [Omarchy shell integration](docs/omarchy-shell.md)
- [Touch, S Pen and app lifecycle results](docs/input-bringup.md)
- [Desktop audio results](docs/audio-bringup.md)
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
