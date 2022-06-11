#!/usr/bin/env bash

# Based on https://docs.gitlab.com/runner/executors/custom_examples/libvirt.html

# /opt/libivrt-driver/prepare.sh

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${currentDir}/base.sh # Get variables from base script.

set -eo pipefail

# trap any error, and mark it as a system failure.
trap "exit $SYSTEM_FAILURE_EXIT_CODE" ERR

# Copy base disk to use for Job.
qemu-img create -f qcow2 -b "$BASE_VM_IMAGE" "$VM_IMAGE"

# Install the VM
virt-install \
    --name "$VM_ID" \
    --os-variant debian10 \
    --disk "$VM_IMAGE" \
    --import \
    --vcpus=4 \
    --ram=8192 \
    --network network=default \
    --graphics none \
    --noautoconsole

# Wait for VM to get IP
echo 'Waiting for VM to get IP'
for i in $(seq 1 120); do
    VM_IP=$(_get_vm_ip)

    if [ -n "$VM_IP" ]; then
        echo "VM got IP: $VM_IP"
        break
    fi

    if [ "$i" == "120" ]; then
        echo 'Waited 120 seconds for VM to start, exiting...'
        # Inform GitLab Runner that this is a system failure, so it
        # should be retried.
        exit "$SYSTEM_FAILURE_EXIT_CODE"
    fi

    sleep 1s
done

# Cleanup known_hosts
rm -f "/root/.ssh/known_hosts.old"
ssh-keygen -f "/root/.ssh/known_hosts" -R "$VM_IP"

# Wait for ssh to become available
echo "Waiting for sshd to be available"
for i in $(seq 1 60); do
    if ssh -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no gitlab-runner@"$VM_IP" >/dev/null 2>/dev/null; then
        break
    fi

    if [ "$i" == "60" ]; then
        echo 'Waited 60 seconds for sshd to start, exiting...'
        # Inform GitLab Runner that this is a system failure, so it
        # should be retried.
        exit "$SYSTEM_FAILURE_EXIT_CODE"
    fi

    sleep 1s
done
