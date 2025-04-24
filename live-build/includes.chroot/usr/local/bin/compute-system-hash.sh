#!/usr/bin/env bash

trap '' SIGINT SIGTSTP SIGTERM

set -euo pipefail

#hardcoded to nvme for now
mount -o ro /dev/nvme0n1p1 /mnt

# Check for the VxLinux-signed.efi and handle if it doesn't exist
# That aside, we're using the strings command to extract the verity hash
# from the signed efi binary to later use when calculating the SHV
if [[ -f /mnt/EFI/debian/VxLinux-signed.efi ]]; then
  VERITY_HASH=$(strings /mnt/EFI/debian/VxLinux-signed.efi | grep -o verity.hash=[a-zA-Z0-9]* | cut -d'=' -f2)
else
  VERITY_HASH=""
fi

umount /mnt

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
