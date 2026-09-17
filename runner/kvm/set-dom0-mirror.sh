#!/bin/bash

# Point dom0's repos at a local mirror instead of the public metalinks.

set -euo pipefail

MIRROR="${1:?usage: set-dom0-mirror.sh <mirror-base-url> [qubes-release] [reposdir]}"
RELEASE="${2:-4.3}"
REPOSDIR="${3:-/etc/yum.repos.d}"
MIRROR="${MIRROR%/}"

MAP="fedora=$MIRROR/fedora/releases/\$releasever/Everything/\$basearch/os/
updates=$MIRROR/fedora/updates/\$releasever/Everything/\$basearch/
qubes-dom0-current=$MIRROR/qubesos/repo/yum/r$RELEASE/current/dom0/fc\$releasever/
qubes-dom0-current-testing=$MIRROR/qubesos/repo/yum/r$RELEASE/current-testing/dom0/fc\$releasever/
qubes-dom0-security-testing=$MIRROR/qubesos/repo/yum/r$RELEASE/security-testing/dom0/fc\$releasever/"

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

echo "dom0 repos now pointing at $MIRROR:"
grep -rn '^baseurl=' "$REPOSDIR"/ || true
