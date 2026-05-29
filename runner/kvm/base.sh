#!/bin/bash

# Based on https://docs.gitlab.com/runner/executors/custom_examples/libvirt.html

# /opt/libvirt-driver/base.sh

set -eo pipefail

VM_IMAGES_PATH="/var/lib/libvirt/images"

# Translate a docker-style image reference (fedora:42, qubesos:4.3,
# qubesos:4.3-debian, debian, ...) into the on-disk qcow2 filename
# produced by generate-vm.sh. Empty tag means the versionless symlink
# (which itself points at the highest version on disk). Returns 1 on
# unknown distro so the caller can fall back to literal filename
# matching for backward compatibility.
resolve_vm_image() {
    local ref="$1" distro tag version flavor
    if [[ "$ref" == *:* ]]; then
        distro="${ref%%:*}"
        tag="${ref#*:}"
    else
        distro="$ref"
        tag=""
    fi
    case "$distro" in
        fedora|debian)
            if [ -n "$tag" ]; then
                echo "gitlab-runner-${distro}-${tag}.qcow2"
            else
                echo "gitlab-runner-${distro}.qcow2"
            fi
            ;;
        qubesos)
            # tag forms: "" | "4.3" | "debian" | "4.3-debian"
            if [[ "$tag" == *-* ]]; then
                version="${tag%-*}"
                flavor="${tag##*-}"
            elif [[ "$tag" =~ ^[0-9] ]]; then
                version="$tag"
                flavor=""
            else
                version=""
                flavor="$tag"
            fi
            local prefix="qubes"
            [ -n "$flavor" ] && prefix="qubes_${flavor}"
            if [ -n "$version" ]; then
                echo "${prefix}_${version}_64bit_stable.qcow2"
            else
                echo "${prefix}_64bit_stable.qcow2"
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

if [ -n "${CUSTOM_ENV_VM_IMAGE:-}" ]; then
    if resolved=$(resolve_vm_image "$CUSTOM_ENV_VM_IMAGE") \
       && [ -e "$VM_IMAGES_PATH/$resolved" ]; then
        BASE_VM_IMAGE="$VM_IMAGES_PATH/$resolved"
    elif [ -e "$VM_IMAGES_PATH/$CUSTOM_ENV_VM_IMAGE" ]; then
        BASE_VM_IMAGE="$VM_IMAGES_PATH/$CUSTOM_ENV_VM_IMAGE"
    else
        echo "VM_IMAGE '$CUSTOM_ENV_VM_IMAGE' not found (tried '${resolved:-}' and literal)." >&2
        exit 1
    fi
else
    BASE_VM_IMAGE="$VM_IMAGES_PATH/gitlab-runner-fedora.qcow2"
fi

if [ -e /home/gitlab-runner/.ssh/id_ed25519 ]; then
    SSH_KEY=/home/gitlab-runner/.ssh/id_ed25519
elif [ -e /var/lib/gitlab-runner/.ssh/id_ed25519 ]; then
    SSH_KEY=/var/lib/gitlab-runner/.ssh/id_ed25519
else
    echo "Cannot find gitlab-runner's SSH private key."
    exit 1
fi

VM_ID="runner-$CUSTOM_ENV_CI_RUNNER_ID-project-$CUSTOM_ENV_CI_PROJECT_ID-concurrent-$CUSTOM_ENV_CI_CONCURRENT_PROJECT_ID-job-$CUSTOM_ENV_CI_JOB_ID"
VM_IMAGE="$VM_IMAGES_PATH/$VM_ID.qcow2"
VM_SSH_ARGS="-i $SSH_KEY -o StrictHostKeyChecking=no ${CUSTOM_ENV_VM_SSH_EXTRA_ARGS:-}"

_get_vm_ip() {
    # Single-NIC guests (fedora/debian): use NIC1.
    # Qubes guests: NIC1 -> sys-net (irrelevant for SSH), NIC2 -> PCI-
    # passthrough'd to dom0 (sshd lives here), NIC3 -> unused spare.
    # So always prefer NIC2 when present.
    local n mac ip
    n=$(virsh -q domiflist "$VM_ID" 2>/dev/null | awk '$5!=""' | wc -l || true)
    [ -z "$n" ] && return
    [ "$n" = 0 ] && return
    if [ "$n" -ge 2 ]; then
        mac=$(virsh -q domiflist "$VM_ID" 2>/dev/null | awk 'NR==2{print $5}' || true)
    else
        mac=$(virsh -q domiflist "$VM_ID" 2>/dev/null | awk 'NR==1{print $5}' || true)
    fi
    [ -z "$mac" ] && return
    for src in lease arp agent; do
        ip=$(virsh -q domifaddr "$VM_ID" --source "$src" 2>/dev/null \
            | awk -v m="$mac" 'tolower($2)==tolower(m){print $4}' \
            | sed -E 's|/([0-9]+)?$||' \
            | head -1 || true)
        [ -n "$ip" ] && { echo "$ip"; return 0; }
    done
    return 0
}

cleanup() {
    local exit_code=$?

    # Destroy VM (ignore errors: VM may have already stopped or never started).
    virsh destroy "$VM_ID" 2>/dev/null || true

    if [ "${CUSTOM_ENV_NO_CLEANUP:-}" != 1 ]; then
        # Undefine VM (ignore errors: may already be undefined).
        virsh undefine "$VM_ID" 2>/dev/null || true

        # Delete VM disk.
        if [ -f "$VM_IMAGE" ]; then
            rm -rf "$VM_IMAGE" "${VM_IMAGE}-extra"
        fi
    fi

    if [ "${exit_code}" -ge 1 ]; then
        echo "ERROR: An error occurred during job execution."
    fi

    exit "${exit_code}"
}
