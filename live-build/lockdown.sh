#!/bin/bash
# NOTE: This script is intended for VotingWorks use when creating
# signed and verified releases. It includes assumptions about how
# keys are stored and accessed and may not work outside of those 
# assumptions. If you're interested in creating your own signed+verified
# releases and can't adapt this script to your needs, feel free to
# reach out and we'll do our best to help.
#

if [[ $EUID -ne 0 ]]; then
  echo "Please run this script as root via: sudo $0"
  exit 1
fi

loopback_img=$1

if [[ -z "$loopback_img" ]]; then
  echo "Usage: $0 /path/to/vxdbkey.img"
  exit 1
fi

if [[ ! -f $loopback_img ]]; then
  echo "Error: Could not find $loopback_img"
  exit 1
fi

tmp_build_dir="tmp-build-dir"
bundle_dir="${tmp_build_dir}/assets"
bootx64_efi="${bundle_dir}/BOOTX64.EFI"
vx64_efi="${bundle_dir}/VX64.EFI"
vxiso_tarball="vx-iso-assets.tgz"

if [[ ! -d "${bundle_dir}" ]]; then
  echo "There is not a valid directory at ${bundle_dir}"
  exit 1
fi

# Create the cmdline for this release
verity_hash=$(cat ${bundle_dir}/live/filesystem.squashfs.roothash)
verity_cmdline_file="/tmp/veritycmdline"
sed -e s/VERITY_HASH_PLACEHOLDER/${verity_hash}/ veritycmdline > $verity_cmdline_file

# Create an updated VX64.EFI w/ verity hash included
objcopy --update-section .cmdline=${verity_cmdline_file} ${vx64_efi} ${vx64_efi}.updated

# Replace the original with the updated version
mv ${vx64_efi}.updated $vx64_efi

# Create a temporary mount location for secure boot keys
key_mnt="/tmp/key_mnt"
mkdir -p $key_mnt

# Mount the secure boot keys img file as a loopback device
mount -o loop $loopback_img $key_mnt

bootx64_efi="${bundle_dir}/BOOTX64.EFI"
vx64_efi="${bundle_dir}/VX64.EFI"
# Sign EFI files
sbsign --key=${key_mnt}/DB.key --cert=${key_mnt}/DB.crt --output ${bootx64_efi}.signed ${bootx64_efi}
sbsign --key=${key_mnt}/DB.key --cert=${key_mnt}/DB.crt --output ${vx64_efi}.signed ${vx64_efi}

# Replace previous versions with the signed versions
mv ${bootx64_efi}.signed $bootx64_efi
mv ${vx64_efi}.signed $vx64_efi

# Unmount the loopback device
umount $key_mnt

# Remove the temporary mount location
rm -rf $key_mnt

# Recreate the bundle with locked down files
echo "Recreating tarball of all assets"
cd $bundle_dir
if [[ -f $vxiso_tarball ]]; then
  rm $vxiso_tarball
fi
tar cfz ${vxiso_tarball} *

echo "Lockdown is complete. Continue with normal vx-iso build processes."

exit 0
