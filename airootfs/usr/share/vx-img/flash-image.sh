#!/bin/bash
echo "Flashing a new image to the hard disk. This will destroy any existing data on the disk. Continue? [y/N]:"

read answer

if [[ $answer != 'y' && $answer != 'Y' ]]; then
    exit
fi

echo "Mounting data partition"
mount /dev/sda3 /mnt

echo "Decompressing and writing:"
lz4 -c -d /mnt/image.img.lz4 | pv -s 50g > /dev/nvme0n1 

echo "Now checking that the write was successful."
echo "The hash should be:"
cat /usr/share/vx-img/image.sha256sum 

echo "Computing hash..."
head -c 50G /dev/nvme0n1 | pv -s 50g | sha256sum
