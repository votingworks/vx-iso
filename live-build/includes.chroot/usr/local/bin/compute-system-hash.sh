#!/usr/bin/env bash

trap '' SIGINT SIGTSTP SIGTERM

set -euo pipefail

echo "TODO: Implement verify hash generation from vx-iso against installed image"

sleep 10

exit 0

#VERITY_HASH="$(cat /proc/cmdline | awk -F'verity.hash=' '{print $2}' | cut -d' ' -f1)"

#if [[ ! -z "${VERITY_HASH}" ]]; then
    #echo "${VERITY_HASH}"
#else
    #echo "UNVERIFIED"
#fi
