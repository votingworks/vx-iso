#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "Please run this script as root via: sudo $0"
  exit 1
fi

usb_path=$1
bios_dir=$2

if [[ -z "$usb_path" ]]; then
  echo "Usage: $0 /dev/sdX /path/to/bios_dir"
  echo "You must specify the device path to the USB, e.g. /dev/sda"
  exit 1
fi

if [[ -z "$bios_dir" ]]; then
  echo "Usage: $0 /dev/sdX /path/to/bios_dir"
  echo "You must specify the path to the directory containing the BIOS files"
  exit 1
fi

if [[ ! -d "$bios_dir" ]]; then
  echo "Error: $bios_dir is not a directory"
  exit 1
fi

is_removable=$(cat /sys/block/$(basename $usb_path)/removable || echo 0)

if [[ $is_removable == 0 ]]; then
  echo "The device path you specified is not a removable device."
  echo "Please check the device path ($usb_path) you provided."
  exit 1
fi

check_mount=$(findmnt -n -o TARGET "${usb_path}1")
echo "Check mount: ${check_mount}"
if [[ ! -z "${check_mount}" ]]; then
  echo "Already mounted, unmount to be sure"
  umount "${check_mount}"
  sleep 2
fi

if [[ ! -f BOOTX64.EFI ]]; then
  echo "The BOOTX64.EFI file could not be found. Attempting to download..."
  ./download-efi.sh

  if [[ ! -f BOOTX64.EFI ]]; then
    echo "Error: The BOOTX64.EFI file could not be downloaded. Exiting."
    exit 1
  fi
fi

echo "Mounting ${usb_path}1 to /mnt"
mount "${usb_path}1" /mnt

echo "Copying boot files..."
cp BOOTX64.EFI /mnt/EFI/BOOT/
cp STARTUP.NSH /mnt/EFI/BOOT/

echo "Copying all BIOS update files..."
for file in $bios_dir/*
do
  cp $file /mnt/EFI/BOOT/$(basename $file)
done

sync

umount /mnt

exit 0
