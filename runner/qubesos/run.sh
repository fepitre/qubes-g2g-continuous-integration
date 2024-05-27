#!/bin/bash

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${currentDir}"/base.sh

trap "exit $SYSTEM_FAILURE_EXIT_CODE" ERR

check_dispvm_name

qvm-run-vm -- "$DISPVM_NAME" /bin/bash < "${1}"
