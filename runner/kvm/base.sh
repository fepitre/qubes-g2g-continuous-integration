#!/bin/bash

# Based on https://docs.gitlab.com/runner/executors/custom_examples/libvirt.html

# /opt/libvirt-driver/base.sh

set -eo pipefail

VM_IMAGES_PATH="/var/lib/libvirt/images"

if [ -n "${CUSTOM_ENV_VM_IMAGE:-}" ] && [ -e "$VM_IMAGES_PATH/${CUSTOM_ENV_VM_IMAGE}" ]; then
    BASE_VM_IMAGE="$VM_IMAGES_PATH/${CUSTOM_ENV_VM_IMAGE}"
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
        [ -n "$ip" ] && { echo "$ip"; return; }
    done
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
