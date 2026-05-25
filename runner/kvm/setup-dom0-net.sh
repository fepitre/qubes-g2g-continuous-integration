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

printf 'nameserver 9.9.9.9\n' > /etc/resolv.conf

qvm-run -p --no-gui -u root sys-net "cat > /rw/config/qubes-firewall-user-script" <<'EOF'
#!/bin/sh
set -e

for c in prerouting_nat postrouting_dom0; do
    nft delete chain ip qubes $c 2>/dev/null || true
done

# qubes-firewall reruns this script on every reload, so without this the rules duplicate.
nft -a list chain ip qubes custom-forward 2>/dev/null \
    | sed -n '/10\.137\.99\.1/s/.*handle \([0-9][0-9]*\).*/\1/p' \
    | while read h; do nft delete rule ip qubes custom-forward handle "$h" || true; done

nft -a list chain ip qubes-firewall qubes-forward 2>/dev/null \
    | sed -n '/10\.137\.99\.1/s/.*handle \([0-9][0-9]*\).*/\1/p' \
    | while read h; do nft delete rule ip qubes-firewall qubes-forward handle "$h" || true; done

nft 'add chain ip qubes prerouting_nat { type nat hook prerouting priority dstnat; }'
nft add rule ip qubes prerouting_nat iifname != "vif*" tcp dport 22 dnat to 10.137.99.1

nft 'add chain ip qubes postrouting_dom0 { type nat hook postrouting priority srcnat; }'
nft add rule ip qubes postrouting_dom0 ip saddr 10.137.99.1 oifname != "vif*" masquerade

nft add rule ip qubes custom-forward tcp dport 22 ip daddr 10.137.99.1 accept
nft add rule ip qubes-firewall qubes-forward ip saddr 10.137.99.1 accept
EOF

qvm-run -p --no-gui -u root sys-net 'chmod +x /rw/config/qubes-firewall-user-script && systemctl restart qubes-firewall'
