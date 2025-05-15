#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "Please run this script as root via: sudo $0"
  exit 1
fi

usb_path=$1
tmp_build_dir="tmp-build-dir"
bundle_dir="${tmp_build_dir}/assets"

if [[ -z "$usb_path" ]]; then
  echo "Usage: $0 /dev/sdX"
  echo "You must specify the device path to the USB, e.g. /dev/sda"
  exit 1
fi

is_removable=$(cat /sys/block/$(basename $usb_path)/removable || echo 0)

if [[ $is_removable == 0 ]]; then
  echo "The device path you specified is not a removable device."
  echo "Please check the device path ($usb_path) you provided."
  exit 1
fi

check_mount=$(findmnt -n -o TARGET "${usb_path}1")
echo "Checkmount: ${check_mount}"
if [[ ! -z "${check_mount}" ]]; then
  echo "Already mounted, unmount to be sure"
  umount "${check_mount}"
  sleep 2
fi

echo "Mounting ${usb_path}1 to /mnt"
mount "${usb_path}1" /mnt

echo "Copying all EFI boot assets..."
for file in STARTUP.NSH BOOTX64.EFI VX64.EFI
do
  cp "${bundle_dir}/${file}" /mnt/EFI/BOOT/
done

# This is necessary to avoid booting older kernels if present
if [[ -d /mnt/live ]]; then
  if ls /mnt/live/* > /dev/null 2>&1
  then
    echo "Clearing any pre-existing live filesystem resources"
    rm /mnt/live/*
  fi
fi

echo "Copying live filesystem assets..."
cp ${bundle_dir}/live/* /mnt/live/

sync

umount /mnt

exit 0
