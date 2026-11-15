# omarchy-mobile

Experimental native Linux and Omarchy bring-up for the Samsung Galaxy Tab S6 Lite 2022 Wi-Fi (SM-P613 / gta4xlveu).

Current milestone: step 8 passed on SM-P613 — native Linux, USB/SSH, GPU compute, verified graphics readback and continuously animated Weston on the 1200 × 2000 panel. Android was restored and all four protected image hashes verified after step 8. Step 9 is in progress: initial native Arch SSD-root access passed, but an NBD reconnect/mount attempt lost USB/SSH; Android has been restored and all four original hashes verified. A RAM-only Arch root is being prepared to remove NBD from further graphics tests.

- [Plan](PLAN.md) · [Architecture](ARCHITECTURE.md) · [Steps](STEPS.md) · [Progress](PROGRESS.md)
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
