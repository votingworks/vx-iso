#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "Please run this script as root via: sudo $0"
  exit 1
fi

usb_path=$1

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

# In case the drive automounted, unmount
echo "Checking for any active mounts for ${usb_path}..."
for mount in $(lsblk -o MOUNTPOINT -n ${usb_path})
do
  echo "Unmounting ${mount}..."
  umount ${mount}
done

sleep 5

echo "Creating vxmark-bios-update.iso ..."
dd if=${usb_path} of=vxmark-bios-update.iso bs=256M count=1

exit 0
