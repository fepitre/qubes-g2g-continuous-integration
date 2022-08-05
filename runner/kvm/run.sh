#!/usr/bin/env bash

# Based on https://docs.gitlab.com/runner/executors/custom_examples/libvirt.html

# /opt/libvirt-driver/run.sh

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${currentDir}"/base.sh # Get variables from base script.

VM_IP=$(_get_vm_ip)

if ! ssh -i /root/.ssh/id_rsa_gitlab -o StrictHostKeyChecking=no gitlab-runner@"$VM_IP" /bin/bash < "${1}"; then
    # Exit using the variable, to make the build as failure in GitLab CI.
    exit "$BUILD_FAILURE_EXIT_CODE"
fi
