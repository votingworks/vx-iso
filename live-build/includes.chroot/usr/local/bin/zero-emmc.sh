#!/bin/bash
# Zeroes out the very specific emmc drive config present in
# some of our current hardware. This depends on /dev/mmcblk0 existing.
# This script is NOT intended to dynamically attempt to detect
# emmc drives, only to zero out an edge case for production hardware.
#

trap '' SIGINT SIGTSTP SIGTERM

device_path="/dev/mmcblk0"

if [[ -b "${device_path}" ]]; then
  echo "Found a valid block device at ${device_path}."
  echo "The device will be zeroed out. This will take some time."
  # We're going to use a bs=4M option with dd, so calculate how
  # many blocks are needed. This is technically unnecessary
  # because we could let dd write until it runs out of space,
  # but I don't like the error message, so here we are.
  device_size=$( blockdev --getsize64 ${device_path} )
  num_blocks=$(( device_size / 1048576 / 4))

  dd if=/dev/zero of="${device_path}" bs=4M count="${num_blocks}" conv=fsync status=progress
  echo "The ${device_path} device has been zeroed out."
  sleep 2
  exit 0
else
  echo "No block device was found at ${device_path}. Exiting."
  sleep 2
  exit 0
fi

exit 0
