# SM-P613 acceptance matrix

Updated 2026-11-19. Pending and blocked entries are not passes. Revision 13 is
a RAM-root developer desktop, not a completed persistent Omarchy installation.

| Check | Status | Evidence / next action |
| --- | --- | --- |
| Native boot, accelerated display | Passed | Hardware tests 06–09; BOOT unchanged in this campaign |
| Mobile launcher, recents, finger and S Pen | Passed, basic coverage | Prior owner checks and lifecycle regressions |
| Wi-Fi authentication, DHCP, DNS, HTTPS | Passed, including R13 repeat | Hardware test 19: owner entered credentials locally; connected address and HTTPS 200 verified |
| Speakers, volume/mute, microphone signal | Passed on prior revisions | Local RAM capture; numerical statistics retained |
| Packaged Power controls, untimed sleep/wake | Passed | Hardware test 18: 12.785 s deep sleep, no RTC alarm |
| Connected-WLAN suspend | Open failure | Repeat with sequential PM callbacks and DBMDX firmware |
| Microphone after resume | Pending | Local capture after measured suspend |
| Extended stability and sleep drain | Pending | Charge first; report duration and measurement resolution |
| USB recovery/reconnect reliability | Open failure | Intermittent host/gadget connectivity remains unresolved |
| Wired keyboard and mouse via OTG | Pending | Peripherals and hub available; establish Wi-Fi control first |
| Bluetooth headphone pairing/audio | Blocked by software | No HCI controller; kernel lacks HCI UART transport. BlueZ and Bluetooth audio routing also absent. Headphones available |
| 3.5 mm headphone jack | Deferred by owner | No wired headphones available |
| Input edge precision, pen pressure/buttons, palm rejection | Pending | Interactive checks required; basic taps do not establish these |
| Sensors and rotation | Pending | Sensor nodes exist; automatic orientation not implemented |
| Secure lock, idle policy, low-battery shutdown | Not implemented | Development backlog, not validated capabilities |

Private raw logs and identifiers remain under ignored `work/hardware-test-19`.
Never commit Wi-Fi secrets or raw microphone recordings. Successful milestones
are committed and pushed; unfinished checks stay open.
