#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "Please run this script as root via: sudo $0"
  exit 1
fi

usb_path=$1
RELEASE_TYPE=${2:-"field"}

if [[ -z "$usb_path" ]]; then
  echo "Usage: $0 /dev/sdX [field|admin|superadmin]"
  echo ""
  echo "You must specify the device path to the USB, e.g. /dev/sda"
  exit 1
fi

if [[ "${RELEASE_TYPE}" != "field" &&
      "${RELEASE_TYPE}" != "admin" &&
      "${RELEASE_TYPE}" != "superadmin" ]]; then

  echo "Usage: $0 /dev/sdX [field|admin|superadmin]"
  echo ""
  echo "You must specify a valid release type. If none is provided, field will"
  echo "be used by default."
  exit 1
fi

tmp_build_dir="tmp-build-dir"
bundle_dir="${tmp_build_dir}/${RELEASE_TYPE}-assets"
if [[ ! -d "${bundle_dir}" ]]; then
  echo "There is not a valid ${RELEASE_TYPE} release to install."
  echo "Please extract a vx-iso release via extract-build-assets.sh"
  exit 1
fi

drive_type=$(lsblk -n --nodeps -o TRAN ${usb_path} 2>/dev/null)

if [[ $drive_type != "usb" ]]; then
  echo "The device path you specified is not a usb device."
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

echo "Setting Data partition permissions..."
mount "${usb_path}3" /mnt
chmod 777 /mnt/.
umount /mnt

exit 0
