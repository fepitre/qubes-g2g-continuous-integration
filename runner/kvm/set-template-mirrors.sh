#!/bin/bash

# Point template repos at the local mirror. virt-customize cannot reach them:
# a template root is a GPT-partitioned LV, and libguestfs has no kpartx.

set -euo pipefail

MIRROR="${1:?usage: set-template-mirrors.sh <mirror-base-url> [qubes-release] [image]}"
RELEASE="${2:-4.3}"
IMG="${3:-/var/lib/libvirt/images/qubes_4.3_64bit_stable.qcow2}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIRRORED_FEDORA="${MIRRORED_FEDORA:-43}"

[ -f "$IMG" ] || { echo "no such image: $IMG" >&2; exit 1; }
if virsh list --name 2>/dev/null | grep -q .; then
    echo "refusing: a VM is running, its overlay would be corrupted" >&2
    exit 1
fi

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
eval "$(guestfish --listen -a "$IMG")"
trap 'guestfish --remote exit 2>/dev/null || true; rm -rf "$WORK"' EXIT
guestfish --remote run

for lv in $(guestfish --remote lvs | grep -E '/vm-[^/]+-root$'); do
    name=$(basename "$lv")
    dm="qubes_dom0-${name//-/--}"

    # largest partition is the root filesystem
    read -r start size <<<"$(guestfish --remote part-list "$lv" 2>/dev/null | awk '
        /part_start:/ { st = $2 }
        /part_size:/  { if ($2 > best) { best = $2; bst = st } }
        END { if (best) print bst / 512, best / 512 }')"
    [ -n "${size:-}" ] || { echo "skip $name: no partitions"; continue; }

    guestfish --remote debug sh "echo 0 $size linear /dev/mapper/$dm $start | dmsetup create tmplroot" >/dev/null
    if ! guestfish --remote mount /dev/mapper/tmplroot / 2>/dev/null; then
        guestfish --remote debug sh "dmsetup remove tmplroot" >/dev/null
        echo "skip $name: root filesystem would not mount"
        continue
    fi

    if [ "$(guestfish --remote exists /etc/yum.repos.d/qubes-r4.repo)" != true ]; then
        echo "skip $name: not an rpm template"
        guestfish --remote umount /
        guestfish --remote debug sh "dmsetup remove tmplroot" >/dev/null
        continue
    fi

    rm -rf "${WORK:?}"/*; mkdir -p "$WORK/repos"
    guestfish --remote glob copy-out '/etc/yum.repos.d/*' "$WORK/repos/"
    guestfish --remote download /etc/dnf/dnf.conf "$WORK/dnf.conf"
    guestfish --remote download /etc/os-release "$WORK/os-release"
    ver=$(sed -n 's/^VERSION_ID=//p' "$WORK/os-release" | tr -d '"')

    # only redirect Fedora for releases the mirror carries; others keep metalink
    mirror_fedora=0
    for v in $MIRRORED_FEDORA; do [ "$v" = "$ver" ] && mirror_fedora=1; done
    echo "== $name (fc$ver, fedora repos $([ "$mirror_fedora" = 1 ] && echo redirected || echo 'left upstream'))"

    MODE=vm MIRROR_FEDORA="$mirror_fedora" DNF_CONF="$WORK/dnf.conf" \
        "$SCRIPT_DIR/set-dom0-mirror.sh" "$MIRROR" "$RELEASE" "$WORK/repos" >/dev/null

    for f in "$WORK"/repos/*.repo; do
        guestfish --remote upload "$f" "/etc/yum.repos.d/$(basename "$f")"
    done
    guestfish --remote upload "$WORK/dnf.conf" /etc/dnf/dnf.conf
    grep -h '^baseurl=' "$WORK"/repos/*.repo | sed 's/^/     /'

    guestfish --remote umount /
    guestfish --remote debug sh "dmsetup remove tmplroot" >/dev/null
done
