#!/bin/bash

# TODO use dmidecode to detect if we're on a Surface Go

# TODO use efi-readvar to detect if our keys are already on this device

echo "Writing new secure boot keys to the device. Proceed? [y/N]:"

read answer

if [[ $answer != 'y' && $answer != 'Y' ]]; then
    echo "Continue without updating secure boot keys? [y/N]:"
    read answer

    if [[ $answer != 'y' && $answer != 'Y' ]]; then
        exit
    fi
else
    SUCCESS=1
    efi-updatevar -f /etc/efi-keys/DB.auth db && efi-updatevar -f /etc/efi-keys/KEK.auth KEK && efi-updatevar -f /etc/efi-keys/PK.auth PK || SUCCESS=0

    if [[ $SUCCESS != 1 ]]; then
        echo "Writing the keys failed. Make sure you're in setup mode in your firmware interface. Continue anyways? [y/N]:" 
        read answer

        if [[ $answer != 'y' && $answer != 'Y' ]]; then
            exit
        fi
    fi
fi


echo "Flashing a new image to the hard disk. This will destroy any existing data on the disk. Continue? [y/N]:"

read answer

if [[ $answer != 'y' && $answer != 'Y' ]]; then
    exit
fi

echo "Mounting data partition"
mount /dev/sda3 /mnt

_path="/mnt"
_supported=('gz' 'lz4')
_hashash=0

_toflash=""
for f in $_path/*; do
    _filename="${f##*/}"
    _extension="${_filename##*.}"

    _compression=""
    if [[ "$_extension" == "gz" ]]; then
        _compression="gzip";
    elif [[ "$_extension" == "lz4" ]]; then
        _compression="lz4";
    elif [[ "#_extension=sha256sum" ]]; then
        _hashash=0
    fi
    
    if [ ! -z "$_compression" ]; then
        echo "Found $f, extract it using $_compression and flash? [y/n]"
        read answer

        if [[ $answer == 'y' || $answer == 'Y' ]]; then
            _toflash=$_filename
            break
        fi
    fi
done

echo "Extracting and flashing $_toflash"

if [[ $_compression == "gzip" ]]; then
    _finalsize=$($_compression -l | tail -n 1 | sed 's/\s\+[0-9]\+\s\+\([0-9]\+\).*/\1/')
else
    echo "lz4 doesn't support storing the uncompressed data size in the compressed file. Please enter the uncompressed size (default is 64g):"
    read _finalsize
fi

echo "would have run..."
echo "$_compression -c -d $_path/$_filename | pv -s $_finalsize > /dev/nvme0n1"
exit

_toflash=""
for f in $_path/*; do
    _filename="${f##*/}"
    _extension="${_filename##*.}"

    _compression=""
    if [[ "$_extension" == "gz" ]]; then
        _compression="gzip";
    elif [[ "$_extension" == "lz4" ]]; then
        _compression="lz4";
    elif [[ "#_extension=sha256sum" ]]; then
        _hashash=0
    fi
    
    if [ ! -z "$_compression" ]; then
        echo "Found $f, extract it using $_compression and flash? [y/n]"
        read answer

        if [[ $answer == 'y' || $answer == 'Y' ]]; then
            _toflash=$_filename
            break
        fi
    fi
done

echo "Extracting and flashing $_toflash"

echo "What is the expected final size of the image? [64g]:"
read _finalsize

if [[ -z $_finalsize ]]; then
    _finalsize="64g"
fi

$_compression -c -d $_path/$_filename | pv -s $_finalsize > /dev/nvme0n1

if [ $_hashash == 1 ]; then 
    echo "Now checking that the write was successful."
    echo "The hash should be:"
    cat /usr/share/vx-img/image.sha256sum 

    echo "Computing hash..."
    head -c $_finalsize /dev/nvme0n1 | pv -s $_finalsize | sha256sum
fi

if [ $_hashash == 1 ]; then 
    echo "Now checking that the write was successful."
    echo "The hash should be:"
    cat /usr/share/vx-img/image.sha256sum 

    echo "Computing hash..."
    head -c $_finalsize /dev/nvme0n1 | pv -s $_finalsize | sha256sum
fi

# TODO make sure this works on every device
echo "adding a boot entry for Debian shim"
efibootmgr \
	--create \
	--disk /dev/nvme0n1 \
	--part 1 \
	--label "grub" \
	--loader "\\EFI\\debian\\shimx64.efi"


echo "adding a boot entry for VxLinux"
efibootmgr \
	--create \
	--disk /dev/nvme0n1 \
	--part 1 \
	--label "VxLinux" \
	--loader "\\EFI\\debian\\VxLinux-signed.efi"
