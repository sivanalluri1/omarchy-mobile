#!/bin/sh
# Apply a wlan0 lease only to native RAM networking. USB recovery is untouched.
set -eu
[ "$(uname -r)" = 4.14.357-openela-perf-g21b136df1533 ]
[ -f /run/arch-root-mounted ]
[ "$interface" = wlan0 ]
ipv4() {
    echo "$1" | awk -F. 'NF!=4 {exit 1} {for(i=1;i<=4;i++) if($i !~ /^[0-9]+$/ || $i>255) exit 1}'
}
case "$1" in
deconfig) ip addr flush dev wlan0;;
bound|renew)
    ipv4 "$ip"; ipv4 "$subnet"
    ifconfig wlan0 "$ip" netmask "$subnet" up
    gateway=${router%% *}
    if [ -n "$gateway" ]; then
        ipv4 "$gateway"
        ip route replace default via "$gateway" dev wlan0 metric 50
    fi
    : >/etc/resolv.conf
    for server in $dns; do
        ipv4 "$server"
        echo "nameserver $server" >>/etc/resolv.conf
    done
    printf '{"lease_applied":true,"ipv4":"%s"}\n' "$ip" >/run/p613-dhcp-result.json
    ;;
esac
