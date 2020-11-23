#!/usr/bin/env bash

# Based on https://docs.gitlab.com/runner/executors/custom_examples/libvirt.html

# /opt/libivrt-driver/cleanup.sh

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${currentDir}/base.sh # Get variables from base script.

set -eo pipefail

# Destroy VM.
virsh shutdown "$VM_ID"

if [ "${CUSTOM_ENV_NO_CLEANUP}" != 1 ]; then
    # Undefine VM.
    virsh undefine "$VM_ID"
    
    # Delete VM disk.
    if [ -f "$VM_IMAGE" ]; then
        rm "$VM_IMAGE"
    fi
fi
