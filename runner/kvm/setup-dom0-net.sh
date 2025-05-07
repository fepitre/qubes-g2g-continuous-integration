#!/bin/sh

set -x
set -e
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
qvm-run -p --no-gui -u root sys-net iptables -t nat -I PREROUTING '!' -i vif+ -p tcp --dport 22 -j DNAT --to 10.137.99.1
qvm-run -p --no-gui -u root sys-net iptables -I FORWARD -p tcp --dport 22 -d 10.137.99.1 -j ACCEPT || :
qvm-run -p --no-gui -u root sys-net nft add rule ip qubes custom-forward tcp dport ssh accept || :