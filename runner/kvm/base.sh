#!/bin/bash

# Based on https://docs.gitlab.com/runner/executors/custom_examples/libvirt.html

# /opt/libvirt-driver/base.sh

VM_IMAGES_PATH="/var/lib/libvirt/images"

if [ -n "${CUSTOM_ENV_VM_IMAGE}" ] && [ -e "$VM_IMAGES_PATH/${CUSTOM_ENV_VM_IMAGE}" ]; then
    BASE_VM_IMAGE="$VM_IMAGES_PATH/${CUSTOM_ENV_VM_IMAGE}"
else
    BASE_VM_IMAGE="$VM_IMAGES_PATH/gitlab-runner-fedora.qcow2"
fi

if [ -e /home/gitlab-runner/.ssh/id_rsa ]; then
  SSH_KEY=/home/gitlab-runner/.ssh/id_rsa
elif [ -e /var/lib/gitlab-runner/.ssh/id_rsa ]; then
  SSH_KEY=/var/lib/gitlab-runner/.ssh/id_rsa
else
  echo "Cannot find gitlab-runner's SSH public key."
  exit 1
fi

VM_ID="runner-$CUSTOM_ENV_CI_RUNNER_ID-project-$CUSTOM_ENV_CI_PROJECT_ID-concurrent-$CUSTOM_ENV_CI_CONCURRENT_PROJECT_ID-job-$CUSTOM_ENV_CI_JOB_ID"
VM_IMAGE="$VM_IMAGES_PATH/$VM_ID.qcow2"
VM_SSH_ARGS="-i $SSH_KEY -o StrictHostKeyChecking=no ${CUSTOM_ENV_VM_SSH_EXTRA_ARGS:-}"

_get_vm_ip() {
    virsh -q domifaddr "$VM_ID" | awk '{print $4}' | sed -E 's|/([0-9]+)?$||'
}

cleanup() {
    local exit_code=$?

    # Destroy VM.
    virsh destroy "$VM_ID"

    if [ "${CUSTOM_ENV_NO_CLEANUP}" != 1 ]; then
        # Undefine VM.
        virsh undefine "$VM_ID"

        # Delete VM disk.
        if [ -f "$VM_IMAGE" ]; then
            rm "$VM_IMAGE"
        fi
    fi

    if [ ${exit_code} -ge 1 ]; then
        echo "ERROR: An error occurred during job execution."
    fi

    exit "${exit_code}"
}
