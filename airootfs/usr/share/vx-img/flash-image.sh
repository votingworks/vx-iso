#!/bin/bash

err=0

# shellcheck source=util.sh
source util.sh

# This is to evade any race conditions with the display buffer that cuts off
# text. See votingworks/vx-iso#21.
sleep 1
clear
# Detect if this disk already has VotingWorks data on it and copy the machine config
vg=$(vgscan | sed -s 's/.*"\(.*\)".*/\1/g')

if [[ -n $vg ]]; then

    dir=$(find "/dev/$vg" -name "var")
    mount "$dir" /mnt

    if [ -d "/mnt/vx/config" ]; then
        echo "Found /vx/config to copy. Press any key to continue."
        read -r
        tar -czvf vx-config.tar.gz /mnt/vx/config
    fi

    umount /mnt
fi
clear

function flash_keys() {
    # use dmidecode to detect if we're on a Surface Go
    if dmidecode | grep -q 'Surface Go'; then
        _surface=1
    else
        _surface=0
    fi

    _haskeys=0
    if mokutil --pk > /dev/null; then
        # Make sure the SB keys are ours
        # TODO do something fancier once we've decided on our keys
        _pk=$(mokutil --pk | grep -aq "VotingWorks" && echo 1 || echo 0)
        _kek=$(mokutil --kek | grep -aq "VotingWorks" && echo 1 || echo 0)
        _db=$(mokutil --db | grep -aq "VotingWorks" && echo 1 || echo 0)

        if [[ $_pk == 1 && $_kek == 1 && $_db == 1 ]]; then
            _haskeys=1
        fi
    fi

    if [[ $_surface == 0  && $_haskeys == 0 ]]; then
        echo "Writing new secure boot keys to the device. Proceed? [y/N]:"

        read -r answer

        if [[ $answer != 'y' && $answer != 'Y' ]]; then
            echo "Continue without updating secure boot keys? [y/N]:"
            read -r answer

            if [[ $answer != 'y' && $answer != 'Y' ]]; then
                exit
            fi
        else
            if [[ $_surface == 0 ]]; then
                _setup=$(mokutil --sb-state | grep "Setup Mode")

                if [[ -z $_setup ]]; then
                    echo "Device is not in Setup Mode."
                    echo "Please reboot into the BIOS and enter Setup Mode before continuing."
                    echo "Reboot now? [Y/n]:"
                    read -r answer

                    if [[ $answer != 'n' && $answer != 'N' ]]; then
                        systemctl reboot --firmware-setup
                    else
                        echo "Continue without flashing keys?" 
                        read -r answer

                        if [[ $answer != 'n' && $answer != 'N' ]]; then
                            return
                        else
                            echo "Please put the machine in Setup Mode before trying again."
                            exit
                        fi
                    fi
                fi
            fi
            SUCCESS=1

            # We have to make sure we can write the keys. 
            chattr -i /sys/firmware/efi/efivars/db* 2>&1 /dev/null  
            chattr -i /sys/firmware/efi/efivars/KEK* 2>&1 /dev/null 
            chattr -i /sys/firmware/efi/efivars/PK* 2>&1 /dev/null 

            keys=$(lsblk -x SIZE -nblo NAME,LABEL,SIZE,TYPE | grep -iF "Keys" | awk '{ print $1 }')

            if [[ -z $keys ]]; then
                disk_select "Which disk contains the keys to flash?"
                
                if [[ $err == 1 ]]; then
                    echo "Could not select a disk with keys. Not flashing keys."
                    return
                else
                    part_select "$_diskname" "Which partition contains the keys?" 

                    if [[ $err == 1 ]]; then
                        echo "Could not select a partition with keys. Not flashing keys."
                        return
                    fi

                    keys="${part}"
                fi
            fi
            mkdir -p keys
            mount "/dev/${keys}" keys


            efi-updatevar -f keys/DB.auth db && efi-updatevar -f keys/KEK.auth KEK && efi-updatevar -f keys/PK.auth PK || SUCCESS=0

            umount keys

            if [[ $SUCCESS != 1 ]]; then
                echo "Writing the keys failed. Make sure you're in setup mode in your firmware interface. Continue anyways? [y/N]:" 
                read -r answer

                if [[ $answer != 'y' && $answer != 'Y' ]]; then
                    exit
                fi
            else
                echo "Writing keys succeeded!"
            fi
        fi
    fi
}

flash_keys

clear

data=$(lsblk -x SIZE -nblo NAME,LABEL,SIZE,TYPE | grep -iF "Data" | awk '{ print $1 }')

if [[ -n $data ]]; then
    _datadisk="$data"
    mount "/dev/$_datadisk" /mnt
else
    disk_select "Which disk contains the image to flash?"
    if [[ $err == 1 ]]; then
        echo "Disk selection failed. Could not select an image to flash. Exiting..."
        exit
    fi

    part_select "$_diskname" "Which partition contains the image?"
    if [[ $err == 1 ]]; then
        echo "Partition selection failed. Could not select an image to flash. Exiting..."
        exit
    fi

    mount "/dev/${part}" /mnt
fi


clear
if [[ -n $data ]]; then 
    echo "Found data partition ${_datadisk} and mounted on /mnt"
else
    echo "Mounted data disk ${part} on /mnt"
fi

# Expected file naming scheme
_match="^\d+(\.\d)*G-\d{4}-\d{2}-\d{2}T\d{2}(:|_|\s)\d{2}(:|_|\s)\d{2}(\+|-)\d{2}(:|_|\s)\d{2}-.*\.img\.(gz|lz4)$"
_sizematch="^\d+(\.\d)*G"


_path="/mnt"
_supported=('gz' 'lz4')
_hashash=0

_toflash=""
_images=()
_extensions=()

_matches=()
_matchextensions=()

for f in "$_path"/*; do
    _filename="${f##*/}"
    _extension="${_filename##*.}"

    if (echo "$_filename" | grep -qPo "$_match") ; then
        _matches+=("$_filename")
        _matchextensions+=("$_extension")
    elif [[ "$_extension" == "gz" || "$_extension" == "lz4" ]]; then
        _images+=("$_filename")
        _extensions+=("$_extension")
    elif [[ "$_extension" == "sha256sum" ]]; then
        _hashash=0
    fi
done

if [[ -z ${_matches[0]} &&  -z ${_images[0]} ]]; then
    echo "Found no image to flash. Exiting..."
    exit
fi

if [[ "${#_matches[@]}" == 1 ]]; then
    echo "Found only one image in the right format."
    _toflash=${_matches[0]}
    _extension=${_matchextensions[0]}
    _finalsize=$(echo "$_toflash" | grep -oP "$_sizematch")
elif [[ -n ${_matches[0]} ]]; then
    echo "Found several images that match the expected format."
    unset answer
    menu "${_matches[@]}" "Please select an image to flash" 

    if [[ $err == 1 ]]; then
        echo "Something went wrong, please try again."
        exit
    fi

    if [[ -n $answer ]]; then
        _toflash=${_matches[$answer-1]}
    else
        _toflash=${_matches[-1]}
    fi
    _extension=${_matchextensions[0]}
    _finalsize=$(echo "$_toflash" | grep -oP "$_sizematch")
elif [[ "${#_images[@]}" == 1 ]]; then
    echo "Found only one image that might work."
    _toflash=${_images[0]}
    _extension=${_extensions[0]}
else
    echo "Found the following images that might work."
    unset answer
    menu "${_images[@]}" "Please select an image to flash" 

    if [[ $err == 1 ]]; then
        echo "Something went wrong, please try again."
        exit
    fi

    if [[ -n $answer ]]; then
        _toflash=${_images[$answer-1]}
        _extension=${_extensions[$answer-1]}
    else
        _toflash=${_images[-1]}
        _extension=${_extensions[-1]}
    fi
fi

if [[ $_extension == "lz4" ]]; then
    _compression="lz4"
elif [[ $_extension == "gz" ]]; then
    _compression="gzip"
fi

sleep 3
clear

if [[ -z $_finalsize ]]; then
    echo "What is the expected final size of the image, in GB? [64]:"
    read -r answer
    _finalsize="${answer}G"

    if [[ -z "$answer" ]]; then
        _finalsize="64G"
    fi
fi

_disk="/dev/nvme0n1"

# Get our image size in raw bytes
_size=$(numfmt --from=iec "${_finalsize}")

clear
disk_select "Which disk would you like to flash?" "$_size"

if [[ $err == 1 ]]; then
    echo "No disks were big enough for the image! Exiting..."
    exit
fi

echo "Flashing image" 
echo "$_path/$_toflash"
echo "to disk"
echo "$_datadisk"
echo "Continue? [y/N]"

read -r answer

if [[ $answer != 'y' && $answer != 'Y' ]]; then
    exit
fi

# If the size of the image is decimal, chop off the decimal point and after so
# pv doesn't choke on it. This is fine, since pv is only using the size to
# compute status percentages and will still push the whole file to the disk.
statussize="$(echo "$_finalsize" | cut -d '.' -f 1)"
if ! (echo "$statussize" | grep -qo "G"); then
    statussize="${statussize}G"
fi 
$_compression -c -d $_path/"$_toflash" | pv -s "${statussize}" > "$_datadisk"

sleep 3
if [ $_hashash == 1 ]; then 
    echo "Now checking that the write was successful."
    echo "The hash should be:"
    cat /usr/share/vx-img/image.sha256sum 

    echo "Computing hash..."
    head -c $_finalsize "$_datadisk" | pv -s "${statussize}" | sha256sum
fi

umount /mnt

# Now that we've flashed the image, put /vx/config back if it exists.
if [ -e "vx-config.tar.gz" ]; then
    vg=$(vgscan | sed -s 's/.*"\(.*\)".*/\1/g')

    if [[ -n $vg ]]; then
        dir=$(find "/dev/$vg" -name "var")
        mount "$dir" /mnt

        if [ -d "/mnt/vx/config" ]; then
            tar --extract --file=vx-config.tar.gz --gzip --verbose --keep-directory-symlink -C /
        fi

        umount /mnt
        echo "Replacing /vx/config was successful. Press any key to continue."
        read -r
    fi
fi

# TODO make sure this works on every device
echo "adding a boot entry for Debian shim"
efibootmgr \
	--create \
	--disk "$_datadisk" \
	--part 1 \
	--label "grub" \
	--loader "\\EFI\\debian\\shimx64.efi" \
    --quiet


echo "adding a boot entry for VxLinux"
efibootmgr \
	--create \
	--disk "$_datadisk" \
	--part 1 \
	--label "VxLinux" \
	--loader "\\EFI\\debian\\VxLinux-signed.efi" \
    --quiet

clear
echo "The flash was successful! Press any key to reboot in 5 seconds."
read -r 
sleep 5
reboot
