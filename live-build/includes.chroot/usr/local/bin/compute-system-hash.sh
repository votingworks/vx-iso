#!/usr/bin/env bash

trap '' SIGINT SIGTSTP SIGTERM

set -euo pipefail

# Recalculate the verity hash of an existing, read-only volume
# We use a temporary loopback device to write to as part of veritysetup format
# We fetch the original salt used during lockdown via veritysetup dump
# With that in place, we run the exact same veritysetup format command 
# used during lockdown, just with the explicit salt value and temp loopback
function calculate_verity_hash() {
  verity_salt=$(veritysetup dump /dev/mapper/Vx--vg-hashes | grep Salt | awk '{print $2}')

  # create a temporary loopback device in the vx-iso tmp location
  truncate -s 500M /tmp/verity_hash.img
  loop_device=$(losetup --find --show /tmp/verity_hash.img)

  # recalculate the device hash
  calculated_hash=$(veritysetup format --salt=${verity_salt} /dev/mapper/Vx--vg-root ${loop_device} | grep 'Root hash:' | awk '{print $3}')

  # not necessary, but let's clean up anyway
  losetup -d ${loop_device}
  rm /tmp/verity_hash.img
}

if [[ -e /dev/mapper/Vx--vg-hashes ]]; then
  calculate_verity_hash
  base64_hash=$( echo -n ${calculated_hash} | xxd -r -p | base64 )
  echo "System Hash: ${base64_hash}"
  read -p "Press Enter once you have validated the System Hash."
else
    echo "System Hash: UNVERIFIED"
    read -p "This is not a verified image. Press Enter to continue."
fi

# TODO/Future: Add QR code support that can be verified at check.voting.works
# qrencode -t ANSI "payload" -o -
# where payload is the properly formatted and signed payload
#

exit 0
