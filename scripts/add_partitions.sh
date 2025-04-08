#!/bin/bash
#
usb_path=$1

if [[ -z "$usb_path" ]]; then
  echo "Usage: $0 /dev/sdX"
  echo "You must specify the device path to the USB, e.g. /dev/sda"
  exit 1
fi

is_removable=$(cat /sys/block/$(basename $usb_path)/removable)

if [[ $is_removable == 0 ]]; then
  echo "The device path you specified is not a removable device."
  echo "Please check the device path ($usb_path) you provided."
  exit 2
fi

keys_size_mb=20
sector_size=$(cat /sys/block/$(basename $usb_path)/queue/hw_sector_size)
keys_sectors=$((keys_size_mb * 1024 * 1024 / sector_size))

echo "USB: $usb_path"
echo "KEYS_SIZE_MB: $keys_size_mb MB"
echo "SECTOR_SIZE: $sector_size"
echo "KEYS_SECTORS: $keys_sectors"

last_current_sector=$(fdisk -l $usb_path | awk '/^\/dev/ {print $3}' | sort -n | tail -1)

keys_start=$((last_current_sector + 1))
keys_end=$((keys_start + keys_sectors))

data_start=$((keys_end))

echo "last_current: $last_current_sector"
echo "keys_start: $keys_start"
echo "keys_end: $keys_end"
echo "data_start: $data_start"

# Dump existing partitions
sfdisk --dump $usb_path > /tmp/sfdisk.dump

sed -i -e '/last-lba/d' /tmp/sfdisk.dump

cat <<EOF > /tmp/partition.sfdisk
$(cat /tmp/sfdisk.dump)

# Add keys partition
${usb_path}3 : start=$keys_start, size=$keys_sectors, type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7, name="Keys"

# Add data partition
${usb_path}4 : start=$data_start, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="Data"

EOF

umount ${usb_path}1 || true
umount ${usb_path}2 || true

sfdisk ${usb_path} < /tmp/partition.sfdisk

partprobe $usb_path

sleep 5

mkfs.vfat -n Keys ${usb_path}3

sleep 5

mkfs.ext4 -L Data ${usb_path}4

# The USB drive can sometimes be left in an incorrect GPT state
# It will not affect functionality, but the error messages are annoying
# This will fix it. If the drive is fine, it will have no impact.
echo "w" | fdisk ${usb_path}

exit 0;
