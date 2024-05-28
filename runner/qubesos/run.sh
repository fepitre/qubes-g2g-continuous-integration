#!/bin/bash

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${currentDir}"/base.sh

trap 'cleanup' TERM ERR

# check dispvm name
check_dispvm_name

qvm-run-vm -- "$DISPVM_NAME" /bin/bash < "${1}"
