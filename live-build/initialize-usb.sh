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

echo "Creating partitions..."
dd if=/dev/zero of=${usb_path} bs=512 count=1

parted ${usb_path} mklabel gpt
parted ${usb_path} mkpart ESP fat32 1MiB 4096MiB
parted ${usb_path} set 1 boot on
parted ${usb_path} mkpart primary fat32 4096MiB 4196MiB
parted ${usb_path} mkpart primary ext4 4196MiB 100%

partprobe ${usb_path}

sleep 5

echo "Creating filesystems and labels..."
mkfs.fat -F32 "${usb_path}1"
mkfs.fat -F32 "${usb_path}2"
fatlabel "${usb_path}2" "Keys"
mkfs.ext4 "${usb_path}3"
e2label "${usb_path}3" "Data"

partprobe ${usb_path}

sleep 5

echo "Creating required directories..."
mount "${usb_path}1" /mnt

mkdir -p /mnt/EFI/BOOT
mkdir -p /mnt/live

umount /mnt

exit 0
