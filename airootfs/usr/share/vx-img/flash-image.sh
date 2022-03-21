#!/bin/bash

echo "Writing new secure boot keys to the device. Proceed? [y/N]:"

read answer

if [[ $answer != 'y' && $answer != 'Y' ]]; then
    exit
fi

SUCCESS=1
efi-updatevar -f /etc/efi-keys/DB.auth db && efi-updatevar -f /etc/efi-keys/KEK.auth KEK && efi-updatevar -f /etc/efi-keys/PK.auth PK || SUCCESS=0

if [[ $SUCCESS != 1 ]]; then
    echo "Writing the keys failed. Make sure you're in setup mode in your firmware interface. Exiting." 
    exit
fi


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

# TODO make sure this works on every device
efibootmgr \
	--create \
	--disk /dev/nvme0n1 \
	--part 1 \
	--label "VxLinux" \
	--loader "\\EFI\\debian\\VxLinux-signed.efi"
