#!/bin/bash

# create DispVM name based on project ID and job ID
DISPVM_NAME="ci-$CUSTOM_ENV_CI_PROJECT_ID-$CUSTOM_ENV_CI_JOB_ID"

check_dispvm_name () {
    [[ "$DISPVM_NAME" =~ ^ci-[0-9]+-[0-9]+ ]]
}

cleanup() {
    local exit_code=$?

    # kill dispvm
    qrexec-client-vm -- "$DISPVM_NAME" admin.vm.Kill < /dev/null

    if [ ${exit_code} -ge 1 ]; then
        echo "ERROR: An error occurred during job execution."
    fi

    exit "${exit_code}"
}
