#!/bin/bash

err=0
function menu() {

    # Due to quirks of how bash passes arrays, all args are one array. The
    # prompt Argument gets put at the end of the array, so we have to take it
    # out. 
    items=("$@")
    prompt="${items[-1]}"

    unset 'items[-1]'

    if [ ${#items[@]} -eq 0 ]; then
        err=1
        return 
    fi

    i=1
    for item in "${items[@]}"; do
        echo "$i. $item"
        ((i+=1))
    done

    echo  "$prompt Default: [${items[-1]}]"
    read -r answer
    err=0
}

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
            _setup=$(mokutil --sb-state | grep -q "Setup Mode")

            if [[ -z $setup ]]; then
                echo "Device is not in Setup Mode."
                echo "Please reboot into the BIOS and enter Setup Mode before continuing."
                echo "Reboot now? [Y/n]:"
                read -r answer

                if [[ $answer != 'n' && $answer != 'N' ]]; then
                    reboot 
                else
                    exit
                fi
            fi
        fi
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

clear

data=$(lsblk -x SIZE -nblo NAME,LABEL,SIZE,TYPE | grep "Data" | awk '{ print $1 }')

if [[ -n $data ]]; then
    _datadisk="$data"
    mount "/dev/$_datadisk" /mnt
else 
    readarray disks < <(lsblk -x SIZE -nblo NAME,LABEL,SIZE,TYPE | grep "disk" | awk '{ print $1 }')
    # This dumps the newlines at the end of the entries in the lsblk table
    disks=("${disks[@]//$'\n'/}")

    while true; do 
        # If there's only one disk, no need for a menu
        if [[ ${#disks[@]} == 1 ]]; then
            _diskname=${disks[0]}
            _datadisk="/dev/${disks[0]}"
        else
            unset answer
            menu "${disks[@]}" "Which disk contains the data to flash?"
            if [[ $err == 1 ]]; then
                echo "Something went wrong. Please try again."
                exit
            fi

            if [[ -n $answer ]]; then
                selected="${disks[answer-1]}"

                if [[ -z $selected ]]; then
                    echo "Invalid selection, starting over"
                    sleep 3
                    clear
                    continue
                fi
                _diskname=$selected
                _datadisk="/dev/$selected"
            else
                _diskname=${disks[-1]}
                _datadisk="/dev/${disks[-1]}"
            fi
        fi

        # Get all the partitions on the selected disk
        readarray parts < <(lsblk -x SIZE -nblo NAME,LABEL,SIZE,TYPE | grep "part" | grep "$_diskname" | awk '{ print $1 }')
        parts=("${parts[@]//$'\n'/}")

        # if there's only one partition, no need for a menu
        if [[ ${#parts[@]} == 1 ]]; then
            part=${parts[0]}
        else
            unset answer
            menu "${parts[@]}" "Which partition contains the image?"
            if [[ $err == 1 ]]; then
                echo "Something went wrong. Please try again."
                exit
            fi

            if [[ -n $answer ]]; then
                selected="${parts[answer-1]}"

                if [[ -z $selected ]]; then
                    echo "Invalid selection, starting over"
                    sleep 3
                    clear
                    continue
                fi
                part=$selected
            else
                part=${parts[-1]}
            fi
        fi
        break
    done

    mount "/dev/${part}" /mnt
fi


clear
if [[ -n $data ]]; then 
    echo "Found Ventoy Data partition ${_datadisk} and mounted on /mnt"
else
    echo "Mounted data disk ${_datadisk}${part} on /mnt"
fi

# Expected file naming scheme
_match="^\d+(\.\d)*G-\d{4}-\d{2}-\d{2}T\d{2}(:|_|\s)\d{2}(:|_|\s)\d{2}(\+|-)\d{2}(:|_|\s)\d{2}-.*\.img\.gz$"
_sizematch="^\d+(\.\d)*G"


_path="/mnt"
_supported=('gz' 'lz4')
_hashash=0

_toflash=""
_images=()
_extensions=()

_matches=()

for f in "$_path"/*; do
    _filename="${f##*/}"
    _extension="${_filename##*.}"

    if (echo "$_filename" | grep -qPo "$_match") ; then
        _matches+=("$_filename")
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
    _extension="gz"
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
    _extension="gz"
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
echo "Found the following disks to flash:"
while true; do

    # Get a list of all available disks large enough to take our image, sorted by size
    readarray disks < <(lsblk -x SIZE -nblo NAME,SIZE,TYPE | grep "disk" | awk -v var="$_size" '$2 > var {print $1,$2}')
    # dump newlines
    disks=("${disks[@]//$'\n'/}")

    # remove the data disk, since we don't want to flash it.
    fixed_disks=()
    for value in "${disks[@]}"; do
        name=$(echo "$value" | cut -d ' ' -f 1)
        size=$(echo "$value" | cut -d ' ' -f 2 | numfmt --to=iec)
        if [[ "$_datadisk" != *"$name"* ]]; then
            fixed_disks+=("$name $size")
        fi
    done

    if [[ -z ${disks[0]} ]]; then
        echo "There are no disks big enough for this image! Exiting..."
        exit
    elif [[ "${#fixed_disks[@]}" == 1 ]]; then
        _disk="/dev/$(echo "${fixed_disks[0]}" | cut -d ' ' -f 1)"
    else 
        unset answer
        menu "${fixed_disks[@]}" "Which disk would you like to flash?" 

        if [[ $err == 1 ]]; then
            echo "Something went wrong. Please try again."
            continue
        fi 

        if [[ -n $answer ]]; then
            selected=$(echo "${fixed_disks[answer-1]}" | cut -d ' ' -f 1)

            if [[ -z $selected ]]; then
                echo "Invalid selection, starting over"
                continue
            fi
            _disk="/dev/$selected"
        else
            _disk="/dev/$(echo "${fixed_disks[-1]}" | cut -d ' ' -f 1)"
        fi
    fi
    break
done

echo "Flashing image $_path/$_toflash to disk $_disk. Continue? [y/N]"

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
$_compression -c -d $_path/"$_toflash" | pv -s "${statussize}" > "$_disk"

sleep 3
if [ $_hashash == 1 ]; then 
    echo "Now checking that the write was successful."
    echo "The hash should be:"
    cat /usr/share/vx-img/image.sha256sum 

    echo "Computing hash..."
    head -c $_finalsize "$_disk" | pv -s "${statussize}" | sha256sum
fi

# TODO make sure this works on every device
echo "adding a boot entry for Debian shim"
efibootmgr \
	--create \
	--disk "$_disk" \
	--part 1 \
	--label "grub" \
	--loader "\\EFI\\debian\\shimx64.efi" \
    --quiet


echo "adding a boot entry for VxLinux"
efibootmgr \
	--create \
	--disk "$_disk" \
	--part 1 \
	--label "VxLinux" \
	--loader "\\EFI\\debian\\VxLinux-signed.efi" \
    --quiet

clear
echo "The flash was successful! Press any key to reboot in 5 seconds."
read -r 
sleep 5
reboot
