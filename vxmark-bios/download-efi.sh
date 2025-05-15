#!/bin/bash

shellx64_url="https://github.com/pbatard/UEFI-Shell/releases/download/24H2/shellx64.efi"
shellx64_sha256="b95987046a822088d29d004f622904cd708d467b5268f3b94280de8bf6c7c1b1"
bootx64_efi="BOOTX64.EFI"

# fetch shellx64 to bundle dir
echo "Download the shellx64.efi we use as BOOTX64.EFI"
curl --silent --location "${shellx64_url}" --output "${bootx64_efi}"

calculated_shellx64_sha256=$(sha256sum $bootx64_efi | cut -d' ' -f1)

echo "Comparing checksums..."
if [[ "${calculated_shellx64_sha256}" != "${shellx64_sha256}" ]]; then
  echo "Error! The checksums for the downloaded EFI do not match."
  exit 1
else
  echo "Checksums match."
  echo ""
fi

exit 0
