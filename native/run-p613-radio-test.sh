#!/bin/sh
# Supervised RAM-only radio experiment. Stage with stage-radio-test.py first.
set -eu
[ "$(uname -r)" = 4.14.357-openela-perf-g21b136df1533 ]
grep -q 'Samsung GTA4XLVE EUR PROJECT BRINGUP' /proc/device-tree/model
[ -f /run/arch-root-mounted ]
[ ! -e /run/p613-radio-active ]
[ ! -e /arch/tmp/rmtfs ]
[ "$(cat /sys/bus/msm_subsys/devices/subsys0/name)" = modem ]
seconds=${P613_RADIO_SECONDS:-900}
case "$seconds" in ''|*[!0-9]*) exit 2;; esac
[ "$seconds" -ge 30 ] && [ "$seconds" -le 3600 ]
original_policy=$(cat /sys/bus/msm_subsys/devices/subsys0/restart_level)
children=''
modem_open=0
cleanup() {
    trap - EXIT INT TERM
    ip link set wlan0 down 2>/dev/null || true
    if [ "$modem_open" = 1 ]; then exec 9<&-; fi
    if [ -f /run/p613-rmtfs.pid ]; then
        kill -TERM "$(cat /run/p613-rmtfs.pid)" 2>/dev/null || true
    fi
    for child in $children; do kill -TERM "$child" 2>/dev/null || true; done
    echo "$original_policy" >/sys/bus/msm_subsys/devices/subsys0/restart_level
    rm -f /run/p613-radio-active
}
trap cleanup EXIT
trap 'exit 143' INT TERM
touch /run/p613-radio-active
/tmp/start-p613-radio.sh ipa
count=0
while [ "$(cat /sys/bus/msm_subsys/devices/subsys3/state)" != ONLINE ]; do
    count=$((count+1)); [ "$count" -lt 20 ]; sleep 1
done
/tmp/qrtr-ns -f >/tmp/qrtr-ns.log 2>&1 </dev/null & children="$children $!"
P613_FIRMWARE_DIRECTORY=/vendor/firmware_mnt/image /tmp/pd-mapper >/tmp/pd-mapper.log 2>&1 </dev/null & children="$children $!"
P613_FIRMWARE_DIRECTORY=/vendor/firmware_mnt/image /tmp/tqftpserv >/tmp/tqftpserv.log 2>&1 </dev/null & children="$children $!"
/tmp/prepare-p613-rmtfs.sh
/tmp/start-p613-radio.sh adsp
echo RELATED >/sys/bus/msm_subsys/devices/subsys0/restart_level
exec 9</dev/subsys_modem
modem_open=1
chroot /arch python /tmp/prepare-p613-wlan-mac.py 9<&-
cp /arch/tmp/p613-wlan-mac.bin /vendor/firmware_mnt/image/wlan/qca_cld/wlan_mac.bin
# Firmware service registration may lag the modem's ONLINE state.
count=0
until chroot /arch python /tmp/p613-wlfw-init.py --initialize 9<&-; do
    count=$((count+1)); [ "$count" -lt 3 ]; sleep 2
done
timeout -s TERM -k 5 180 /tmp/start-p613-radio.sh wlan 9<&-
[ -d /sys/class/net/wlan0 ]
ip link set wlan0 up
echo "P613_WLAN_READY duration=${seconds}s"
sleep "$seconds" 9<&-
cmp /dev/sda1 /arch/tmp/rmtfs/modem_fs1
cmp /dev/sda2 /arch/tmp/rmtfs/modem_fs2
cmp /dev/sdf1 /arch/tmp/rmtfs/modem_fsg
cmp /dev/sda3 /arch/tmp/rmtfs/modem_fsc
echo P613_RADIO_TEST_FINISHED
