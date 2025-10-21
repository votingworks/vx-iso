#!/usr/bin/env bash

trap '' SIGINT SIGTSTP SIGTERM

set -euo pipefail

# we only support installing to nvme and emmc drives
# the expected naming convention is nvme0n1 and mmcblk0
# the signed efi should be on the first partition (p1)
# if we can't find our signed efi on either drive, do not calculate a hash
candidate_drives="nvme0n1 mmcblk0"

VERITY_HASH=""

for local_drive in $candidate_drives
do
  local_drive="/dev/${local_drive}"
  if [[ -b $local_drive ]]; then
    if mount -o ro ${local_drive}p1 /mnt > /dev/null 2>&1; then
      if [[ -f /mnt/EFI/debian/VxLinux-signed.efi ]]; then
        VERITY_HASH=$(strings /mnt/EFI/debian/VxLinux-signed.efi | grep -o verity.hash=[a-zA-Z0-9]* | cut -d'=' -f2)
        umount /mnt
        break
      fi
      umount /mnt
    fi
  fi
done

if [[ ! -z "${VERITY_HASH}" ]]; then
  base64_hash=$( echo -n ${VERITY_HASH} | xxd -r -p | base64 )
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
