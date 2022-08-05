#!/usr/bin/env bash

# Based on https://docs.gitlab.com/runner/executors/custom_examples/libvirt.html

# /opt/libvirt-driver/base.sh

VM_IMAGES_PATH="/var/lib/libvirt/images"

BASE_VM_IMAGE="$VM_IMAGES_PATH/gitlab-runner-fedora.qcow2"
if [ "${CUSTOM_ENV_USE_CENTOS_IMAGE}" = 1 ]; then
BASE_VM_IMAGE="$VM_IMAGES_PATH/gitlab-runner-centos.qcow2"
elif [ "${CUSTOM_ENV_USE_UBUNTU_IMAGE}" = 1 ]; then
BASE_VM_IMAGE="$VM_IMAGES_PATH/gitlab-runner-ubuntu.qcow2"
elif [ "${CUSTOM_ENV_USE_DEBIAN_IMAGE}" = 1 ]; then
BASE_VM_IMAGE="$VM_IMAGES_PATH/gitlab-runner-debian.qcow2"
fi

VM_ID="runner-$CUSTOM_ENV_CI_RUNNER_ID-project-$CUSTOM_ENV_CI_PROJECT_ID-concurrent-$CUSTOM_ENV_CI_CONCURRENT_PROJECT_ID-job-$CUSTOM_ENV_CI_JOB_ID"
VM_IMAGE="$VM_IMAGES_PATH/$VM_ID.qcow2"

_get_vm_ip() {
    virsh -q domifaddr "$VM_ID" | awk '{print $4}' | sed -E 's|/([0-9]+)?$||'
}
