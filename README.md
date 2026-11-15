# omarchy-mobile

Experimental native Linux and Omarchy bring-up for the Samsung Galaxy Tab S6 Lite 2022 Wi-Fi (SM-P613 / gta4xlveu).

Current milestone: native Arch, accelerated Hyprland and the real Omarchy 4.5 shell with its mobile status bar run on SM-P613. The clean two-minute shell test passed, including periodic IPC checks, GPU readback and user-confirmed visible output. The tablet is left in native Linux testing mode as authorized. Step 9 remains open for the home/app drawer and service integration; current systemd is unsupported on kernel 4.14. Touch, S Pen and remaining hardware functions are unvalidated.

- [Plan](PLAN.md) · [Architecture](ARCHITECTURE.md) · [Steps](STEPS.md) · [Progress](PROGRESS.md)
- [Omarchy shell integration](docs/omarchy-shell.md)
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
