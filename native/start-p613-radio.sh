#!/bin/sh
# Native RAM experiment only. No Android mounts or persistent data writes.
set -eu
[ "$(uname -r)" = 4.14.357-openela-perf-g21b136df1533 ]
grep -q 'Samsung GTA4XLVE EUR PROJECT BRINGUP' /proc/device-tree/model
[ -f /run/arch-root-mounted ]
[ "$#" -eq 1 ] || exit 2
case "$1" in
ipa)
    [ -c /dev/ipa ]
    [ -f /vendor/firmware_mnt/image/ipa_fws.mdt ]
    printf '1\n' > /dev/ipa
    ;;
adsp)
    [ -f /vendor/firmware_mnt/image/adsp.mdt ]
    printf '1\n' > /sys/kernel/boot_adsp/boot
    ;;
wlan)
    [ -c /dev/wlan ]
    [ -f /vendor/firmware_mnt/image/wlan/qca_cld/WCNSS_qcom_cfg.ini ]
    # The Samsung character-device callback copies three bytes. boot_wlan's
    # sysfs attribute has no store callback in this pinned kernel source.
    printf 'ON\n' > /dev/wlan
    ;;
*) echo 'Usage: start-p613-radio.sh ipa|adsp|wlan' >&2; exit 2;;
esac
