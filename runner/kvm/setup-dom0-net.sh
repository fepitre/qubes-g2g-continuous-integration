#!/bin/sh

set -x
set -e

while ! qvm-start sys-net; do
  sleep 1
done

xl network-attach 0 ip=10.137.99.1 script=/etc/xen/scripts/vif-route-qubes backend=sys-net
sleep 2
dev=$(ls /sys/class/net|sort|head -1)
ip a a 10.137.99.1/24 dev $dev
ip l s $dev up
ip r a default dev $dev
rm -f /etc/resolv.conf
echo -e 'nameserver 10.139.1.1\nnameserver 10.139.1.2' > /etc/resolv.conf
qvm-run -p --no-gui -u root sys-net systemctl stop qubes-firewall
sleep 2

qvm-run -p --no-gui -u root sys-net nft 'add chain ip qubes prerouting_nat { type nat hook prerouting priority 100; }'
qvm-run -p --no-gui -u root sys-net nft add rule ip qubes prerouting_nat iifname != "vif*" tcp dport 22 dnat to 10.137.99.1
qvm-run -p --no-gui -u root sys-net nft add rule ip qubes custom-forward tcp dport ssh accept