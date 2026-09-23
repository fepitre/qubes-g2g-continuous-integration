#!/bin/bash

# The emulated NIC corrupts traffic with offloads on: TLS records fail to decode
# and package downloads abort. udev applies the .link at device setup.

set -euo pipefail

IMG="${1:?usage: set-netvm-offload.sh <image>}"
# sorts before 99-default.link, which matches everything and would win
LINK=/etc/systemd/network/50-qubes-ci-no-offload.link

[ -f "$IMG" ] || { echo "no such image: $IMG" >&2; exit 1; }
if virsh list --name 2>/dev/null | grep -q .; then
    echo "refusing: a VM is running" >&2; exit 1
fi

WORK=$(mktemp -d)
cat > "$WORK/no-offload.link" <<'LINKEOF'
# Offloads corrupt traffic on the emulated NIC.
[Match]
Driver=e1000e e1000 rtl8139 virtio_net

[Link]
TransmitChecksumOffload=false
ReceiveChecksumOffload=false
TCPSegmentationOffload=false
TCP6SegmentationOffload=false
GenericSegmentationOffload=false
GenericReceiveOffload=false
LargeReceiveOffload=false
LINKEOF

eval "$(guestfish --listen -a "$IMG")"
trap 'guestfish --remote exit 2>/dev/null || true; rm -rf "$WORK"' EXIT
guestfish --remote run

for lv in $(guestfish --remote lvs | grep -E '/vm-[^/]+-root$'); do
    name=$(basename "$lv"); dm="qubes_dom0-${name//-/--}"
    read -r start size <<<"$(guestfish --remote part-list "$lv" 2>/dev/null | awk '
        /part_start:/ { st = $2 }
        /part_size:/  { if ($2 > best) { best = $2; bst = st } }
        END { if (best) print bst / 512, best / 512 }')"
    [ -n "${size:-}" ] || continue
    guestfish --remote debug sh "echo 0 $size linear /dev/mapper/$dm $start | dmsetup create nvroot" >/dev/null
    if guestfish --remote mount /dev/mapper/nvroot / 2>/dev/null; then
        if [ "$(guestfish --remote exists /usr/lib/systemd)" = true ]; then
            guestfish --remote mkdir-p /etc/systemd/network
            guestfish --remote upload "$WORK/no-offload.link" "$LINK"
            guestfish --remote chmod 0644 "$LINK"
            echo "== $name: .link installed"
        fi
        guestfish --remote umount /
    fi
    guestfish --remote debug sh "dmsetup remove nvroot" >/dev/null
done
