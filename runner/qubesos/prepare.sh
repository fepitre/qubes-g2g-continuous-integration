#!/bin/bash

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${currentDir}"/base.sh

set -eo pipefail

trap "exit $SYSTEM_FAILURE_EXIT_CODE" ERR

check_dispvm_name

# create dispvm
res="$(printf 'name=%s label=red' "$DISPVM_NAME" | qrexec-client-vm -- dom0 admin.vm.Create.DispVM+gitlab-ci-dvm | tr '\0' '_')"
if [ "$res" != "0_" ]; then
    echo "ERROR: Failed to create $DISPVM_NAME: $res"
    exit 1
fi

# auto_cleanup dispvm
res="$(printf 'true' | qrexec-client-vm -- $DISPVM_NAME admin.vm.property.Set+auto_cleanup | tr '\0' '_')"
if [ "$res" != "0_" ]; then
    echo "ERROR: Failed to set tag: $res"
    exit 1
fi

# start dispvm
res="$(qrexec-client-vm -- "$DISPVM_NAME" admin.vm.Start < /dev/null | tr '\0' '_')"
if [ "$res" != "0_" ]; then
    echo "ERROR: Failed to start $DISPVM_NAME: $res"
    exit 1
fi
