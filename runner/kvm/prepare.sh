#!/bin/bash

# Based on https://docs.gitlab.com/runner/executors/custom_examples/libvirt.html

# /opt/libvirt-driver/prepare.sh

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${currentDir}"/base.sh # Get variables from base script.

set -eo pipefail

# trap any error, and mark it as a system failure.
trap 'cleanup' TERM ERR

# Copy base disk to use for Job.
qemu-img create -f qcow2 -F qcow2 -b "$BASE_VM_IMAGE" "$VM_IMAGE"

# Install the VM
# detect if this is a Qubes image
if [[ "$CUSTOM_ENV_VM_IMAGE" =~ ^qubes ]]; then
  EXTRA_OPTS=(
    --features ioapic.driver=qemu
    --iommu model=intel,driver.intremap="on"
  )

  # extra devices for ansible tests
  qemu-img create -f qcow2 "${VM_IMAGE}-extra" 1G
  EXTRA_OPTS+=(
    --network network=default,model=e1000e \
    --network network=default,model=e1000e \
    --disk "${VM_IMAGE}-extra" \
  )
  VM_CPU="${CUSTOM_ENV_VM_VCPUS:-4}"
  VM_MEMORY="${CUSTOM_ENV_VM_MEMORY:-16384}"
else
  EXTRA_OPTS=()
  VM_CPU="${CUSTOM_ENV_VM_VCPUS:-4}"
  VM_MEMORY="${CUSTOM_ENV_VM_MEMORY:-8192}"
fi

echo "Extra options: ${EXTRA_OPTS[@]}"

virt-install \
    --name "$VM_ID" \
    --os-variant "${CUSTOM_ENV_VM_OS_VARIANT:-fedora41}" \
    --disk       "${VM_IMAGE}" \
    --import \
    --vcpus      "${VM_CPU}" \
    --ram        "${VM_MEMORY}" \
    --network    network=default,model=e1000e \
    --graphics   none \
    --noautoconsole \
    "${EXTRA_OPTS[@]}"

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
rm -f "$HOME/.ssh/known_hosts.old"
if [ -e "$HOME/.ssh/known_hosts" ]; then
    ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$VM_IP"
fi

# Wait for ssh to become available
echo "Waiting for sshd to be available at $VM_IP"
for i in $(seq 1 60); do
    if ssh $VM_SSH_ARGS gitlab-runner@"$VM_IP" >/dev/null 2>/dev/null; then
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
