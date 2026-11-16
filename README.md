# omarchy-mobile

Experimental native Linux and Omarchy bring-up for the Samsung Galaxy Tab S6 Lite 2022 Wi-Fi (SM-P613 / gta4xlveu).

Current milestone: native Arch, accelerated Hyprland and Omarchy's mobile home, app drawer, status bar and recents run on SM-P613. Foot app launching and initial finger/S Pen response and pressure are verified. The final image passed a clean two-minute session and ten app open/close cycles after fixing a Turnip DMA-BUF descriptor leak and using static recents cards. The tablet remains in native Linux testing mode. The Squeekboard on-screen keyboard now passes real typing/Enter, show/hide and five app lifecycle cycles on revision 7. Native Wi-Fi now passes dual-band scans, WPA2 authentication, DHCP, verified HTTPS and reconnect. Revision 9 packages the networking stack and validates the mobile Wi-Fi controls. Audio, power services and remaining hardware validation are still in progress; current systemd is unsupported on kernel 4.14.

- [Plan](PLAN.md) · [Architecture](ARCHITECTURE.md) · [Steps](STEPS.md) · [Progress](PROGRESS.md)
- [Omarchy shell integration](docs/omarchy-shell.md)
- [Touch, S Pen and app lifecycle results](docs/input-bringup.md)
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
