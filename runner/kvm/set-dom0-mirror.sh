#!/bin/bash

# Point dom0 or template repos at a local mirror. MODE=dom0 runs inside the
# image, MODE=vm runs on the host against a mounted template root.

set -euo pipefail

MIRROR="${1:?usage: set-dom0-mirror.sh <mirror-base-url> [qubes-release] [reposdir] [fedora-release]}"
RELEASE="${2:-4.3}"
REPOSDIR="${3:-/etc/yum.repos.d}"
MIRROR="${MIRROR%/}"

MODE="${MODE:-dom0}"
DNF_CONF="${DNF_CONF:-/etc/dnf/dnf.conf}"
QUBES_PUBLIC="${QUBES_PUBLIC:-https://yum.qubes-os.org}"
FEDORA_FALLBACK="${FEDORA_FALLBACK:-https://mirror.in2p3.fr/pub/fedora/linux}"
# vm only: the caller knows which releases the mirror carries
MIRROR_FEDORA="${MIRROR_FEDORA:-0}"
# concurrent large transfers through the Qubes updates proxy get reset
MAX_PARALLEL="${MAX_PARALLEL:-1}"

case "$MODE" in
    dom0)
        # $releasever is the Qubes release here, so resolve Fedora's literally
        FEDORA="${4:-$(rpm -E %fedora 2>/dev/null || true)}"
        case "$FEDORA" in
            '' | *[!0-9]*)
                echo "cannot determine dom0's Fedora release (got '$FEDORA')" >&2
                exit 1
                ;;
        esac
        MAP="fedora=$MIRROR/fedora/releases/$FEDORA/Everything/\$basearch/os/
updates=$MIRROR/fedora/updates/$FEDORA/Everything/\$basearch/
qubes-dom0-current=$MIRROR/qubes/repo/yum/r$RELEASE/current/dom0/fc$FEDORA/ $QUBES_PUBLIC/r$RELEASE/current/dom0/fc$FEDORA
qubes-dom0-current-testing=$MIRROR/qubes/repo/yum/r$RELEASE/current-testing/dom0/fc$FEDORA/ $QUBES_PUBLIC/r$RELEASE/current-testing/dom0/fc$FEDORA
qubes-dom0-security-testing=$MIRROR/qubes/repo/yum/r$RELEASE/security-testing/dom0/fc$FEDORA/ $QUBES_PUBLIC/r$RELEASE/security-testing/dom0/fc$FEDORA"
        ;;
    vm)
        # $releasever is the Fedora release here, so let dnf expand it
        MAP="qubes-vm-r$RELEASE-current=$MIRROR/qubes/repo/yum/r$RELEASE/current/vm/fc\$releasever/ $QUBES_PUBLIC/r$RELEASE/current/vm/fc\$releasever
qubes-vm-r$RELEASE-current-testing=$MIRROR/qubes/repo/yum/r$RELEASE/current-testing/vm/fc\$releasever/ $QUBES_PUBLIC/r$RELEASE/current-testing/vm/fc\$releasever
qubes-vm-r$RELEASE-security-testing=$MIRROR/qubes/repo/yum/r$RELEASE/security-testing/vm/fc\$releasever/ $QUBES_PUBLIC/r$RELEASE/security-testing/vm/fc\$releasever"
        if [ "$MIRROR_FEDORA" = 1 ]; then
            MAP="$MAP
fedora=$MIRROR/fedora/releases/\$releasever/Everything/\$basearch/os/ $FEDORA_FALLBACK/releases/\$releasever/Everything/\$basearch/os/
updates=$MIRROR/fedora/updates/\$releasever/Everything/\$basearch/ $FEDORA_FALLBACK/updates/\$releasever/Everything/\$basearch/"
        fi
        ;;
    *)
        echo "MODE must be dom0 or vm (got '$MODE')" >&2
        exit 1
        ;;
esac

for repo in "$REPOSDIR"/*.repo; do
    [ -f "$repo" ] || continue
    if awk -v map="$MAP" '
        BEGIN {
            n = split(map, lines, "\n")
            for (i = 1; i <= n; i++) {
                eq = index(lines[i], "=")
                url[substr(lines[i], 1, eq - 1)] = substr(lines[i], eq + 1)
            }
        }
        /^[[:space:]]*\[/ {
            section = substr($0, index($0, "[") + 1)
            section = substr(section, 1, index(section, "]") - 1)
            print
            if (section in url) {
                print "baseurl=" url[section]
                changed = 1
            }
            next
        }
        (section in url) && /^[[:space:]]*#?[[:space:]]*(metalink|mirrorlist|baseurl)[[:space:]]*=/ { next }
        { print }
        END { exit !changed }
    ' "$repo" > "$repo.mirror"; then
        mv "$repo.mirror" "$repo"
    else
        rm -f "$repo.mirror"
    fi
done

set_dnf_opt() {   # $1=key $2=value
    if grep -qE "^[[:space:]]*$1[[:space:]]*=" "$DNF_CONF"; then
        sed -i -E "s|^[[:space:]]*$1[[:space:]]*=.*|$1=$2|" "$DNF_CONF"
    elif grep -qE '^\[main\]' "$DNF_CONF"; then
        sed -i -E "0,/^\[main\]/s||[main]\n$1=$2|" "$DNF_CONF"
    else
        printf '[main]\n%s=%s\n' "$1" "$2" >> "$DNF_CONF"
    fi
}

if [ -f "$DNF_CONF" ]; then
    if [ "$MODE" = dom0 ]; then
        # zchunk needs huge Range headers and buys nothing over a LAN
        set_dnf_opt zchunk False
    else
        set_dnf_opt max_parallel_downloads "$MAX_PARALLEL"
        set_dnf_opt timeout 120
    fi
fi

echo "$MODE repos now pointing at $MIRROR:"
grep -rn '^baseurl=' "$REPOSDIR"/ || true
