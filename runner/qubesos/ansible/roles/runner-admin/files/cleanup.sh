#!/bin/bash

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${currentDir}"/base.sh

set -eo pipefail

# check dispvm name
check_dispvm_name

cleanup
