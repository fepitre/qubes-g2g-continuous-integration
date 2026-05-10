#!/bin/bash

# Load runner-specific env (CI_RUNNER_DVM, etc.) written by Ansible
[ -f /etc/gitlab-ci-runner.env ] && source /etc/gitlab-ci-runner.env

# create DispVM name based on project ID and job ID
DISPVM_NAME="ci-$CUSTOM_ENV_CI_PROJECT_ID-$CUSTOM_ENV_CI_JOB_ID"

check_dispvm_name () {
    [[ "$DISPVM_NAME" =~ ^ci-[0-9]+-[0-9]+ ]]
}

cleanup() {
    local exit_code=$?

    qrexec-client-vm -- "$DISPVM_NAME" admin.vm.Kill < /dev/null

    # Kill builder disposables spawned by QubesExecutor inside this CI job before killing the job VM.
    # They are tagged created-by-$DISPVM_NAME and disp-for-executor.
    while IFS= read -r vm; do
        [ -n "$vm" ] || continue
        tags=$(qrexec-client-vm -- "$vm" admin.vm.tag.List < /dev/null 2>/dev/null | tail -c +3) || continue
        echo "$tags" | grep -qxF "created-by-$DISPVM_NAME" || continue
        qrexec-client-vm -- "$vm" admin.vm.Kill < /dev/null 2>/dev/null || true
    done < <(qrexec-client-vm -- dom0 admin.vm.List < /dev/null 2>/dev/null | tail -c +3 | awk '{print $1}')

    if [ ${exit_code} -ge 1 ]; then
        echo "ERROR: An error occurred during job execution."
    fi

    exit "${exit_code}"
}
