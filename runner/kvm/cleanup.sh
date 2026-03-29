#!/bin/bash

# Based on https://docs.gitlab.com/runner/executors/custom_examples/libvirt.html

# /opt/libvirt-driver/cleanup.sh

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${currentDir}"/base.sh # Get variables from base script.

set -eo pipefail

VM_IP=$(_get_vm_ip)

cleanup

# Remove stale known_hosts entries for the ephemeral VM
if [ -n "$VM_IP" ]; then
    if [ -e "$HOME/.ssh/known_hosts" ]; then
        ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$VM_IP" || true
    fi
    if [ -e /root/.ssh/known_hosts ]; then
        ssh-keygen -f /root/.ssh/known_hosts -R "$VM_IP" || true
    fi
fi
