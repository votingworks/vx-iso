#!/bin/bash

# This is to evade any race conditions with the display buffer that cuts off
# text. See votingworks/vx-iso#21.
sleep 1
clear
# use dmidecode to detect if we're on a Surface Go
if dmidecode | grep -q 'Surface Go'; then
    _surface=1
else
    _surface=0
fi


# TODO use efi-readvar to detect if our keys are already on this device
_haskeys=1

if [[ $_surface == 0 && $_haskeys == 0 ]]; then
    echo "Writing new secure boot keys to the device. Proceed? [y/N]:"

    read -r answer

    if [[ $answer != 'y' && $answer != 'Y' ]]; then
        echo "Continue without updating secure boot keys? [y/N]:"
        read -r answer

        if [[ $answer != 'y' && $answer != 'Y' ]]; then
            exit
        fi
    else
        SUCCESS=1
        efi-updatevar -f /etc/efi-keys/DB.auth db && efi-updatevar -f /etc/efi-keys/KEK.auth KEK && efi-updatevar -f /etc/efi-keys/PK.auth PK || SUCCESS=0

        if [[ $SUCCESS != 1 ]]; then
            echo "Writing the keys failed. Make sure you're in setup mode in your firmware interface. Continue anyways? [y/N]:" 
            read -r answer

            if [[ $answer != 'y' && $answer != 'Y' ]]; then
                exit
            fi
        fi
    fi
fi

echo "Flashing a new image to the hard disk. This will destroy any existing data on the disk. Continue? [y/N]:"

read -r answer

if [[ $answer != 'y' && $answer != 'Y' ]]; then
    exit
fi

clear

IFS=$'\n' read -r -d '' -a disks <<< "$(lsblk -x SIZE -nblo NAME,LABEL,SIZE,TYPE | grep "disk" | awk '{print $1}')"

while true; do 
    i=1
    for disk in "${disks[@]}"; do
        echo "$i. /dev/$disk"
        ((i+=1))
    done
    echo "Which disk contains the data to flash? [${disks[-1]}]" 
    read -r answer
    if [[ -n $answer ]]; then
        selected=${disks[answer-1]}

        if [[ -z $selected ]]; then
            echo "Invalid selection, starting over"
            clear
            continue
        fi
        _datadisk="/dev/$selected"
    else
        _datadisk="/dev/${disks[-1]}"
    fi
    break
done

mount "${_datadisk}3" /mnt

clear
echo "Mounted data disk ${_datadisk} on /mnt"

_path="/mnt"
_supported=('gz' 'lz4')
_hashash=0

_toflash=""
_images=()
_extensions=()
for f in "$_path"/*; do
    _filename="${f##*/}"
    _extension="${_filename##*.}"

    if [[ "$_extension" == "gz" || "$_extension" == "lz4" ]]; then
        _images+=("$_filename")
        _extensions+=("$_extension")
    elif [[ "$_extension" == "sha256sum" ]]; then
        _hashash=0
    fi
done

if [[ -z ${_images[0]} ]]; then
    echo "Found no image to flash. Exiting..."
    exit
fi

echo "Found the following images."
i=1
for img in "${_images[@]}"; do
    echo "$i. $img"
    ((i+=1))
done

echo  "Please select one to flash [${_images[-1]}]"
read -r answer

if [[ -n $answer ]]; then
    _toflash=${_images[answer-1]}
    _extension=${_extensions[answer-1]}
else
    _toflash=${_images[-1]}
    _extension=${_extensions[-1]}
fi

if [[ $_extension == "lz4" ]]; then
    _compression="lz4"
elif [[ $_extension == "gz" ]]; then
    _compression="gzip"
fi

echo "Extracting and flashing $_toflash"

clear
echo "What is the expected final size of the image, in GB? [64]:"
read -r _finalsize

if [[ -z $_finalsize ]]; then
    _finalsize="64"
fi

_disk="/dev/nvme0n1"

# Get our image size in raw bytes
_size=$(numfmt --from=iec "${_finalsize}G")

clear
echo "Found the following disks to flash:"
while true; do

    # Get a list of all available disks large enough to take our image, sorted by size
    IFS=$'\n' read -r -d '' -a disks <<< "$(lsblk -x SIZE -nblo NAME,SIZE,TYPE | grep "disk" | awk -v var="$_size" '$2 > var {print $1}')"

    if [[ -z ${disks[0]} ]]; then
        echo "There are no disks big enough for this image! Exiting..."
        exit
    fi

    # Get the sizes of all these disks
    IFS=$'\n' read -r -d '' -a sizes <<< "$(lsblk -x SIZE -nblo NAME,SIZE,TYPE | grep "disk" | awk -v var="$_size" '$2 > var {print $2}')"

    i=1
    for disk in "${disks[@]}"; do
        echo "$i. /dev/$disk $(numfmt --to=iec "${sizes[$i-1]}")"
        ((i+=1))
    done
    

    echo "Which disk would you like to flash? Default: /dev/${disks[-1]}:" 
    read -r answer
    if [[ -n $answer ]]; then
        selected=${disks[answer-1]}

        if [[ -z $selected ]]; then
            echo "Invalid selection, starting over"
            continue
        fi
        _disk="/dev/$selected"
    else
        _disk="/dev/${disks[-1]}"
    fi
    break
done    

echo "Flashing image $_path/$_toflash to disk $_disk"
$_compression -c -d $_path/"$_toflash" | pv -s "${_finalsize}g" > "$_disk"

if [ $_hashash == 1 ]; then 
    echo "Now checking that the write was successful."
    echo "The hash should be:"
    cat /usr/share/vx-img/image.sha256sum 

    echo "Computing hash..."
    head -c $_finalsize "$_disk" | pv -s $_finalsize | sha256sum
fi

# TODO make sure this works on every device
echo "adding a boot entry for Debian shim"
efibootmgr \
	--create \
	--disk "$_disk" \
	--part 1 \
	--label "grub" \
	--loader "\\EFI\\debian\\shimx64.efi"


echo "adding a boot entry for VxLinux"
efibootmgr \
	--create \
	--disk "$_disk" \
	--part 1 \
	--label "VxLinux" \
	--loader "\\EFI\\debian\\VxLinux-signed.efi"
