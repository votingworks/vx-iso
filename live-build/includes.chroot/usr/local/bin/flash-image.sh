#!/bin/bash
# TODO: Convert this to be entirely function based.
# It is currently too confusing to easily follow execution flow.

trap '' SIGINT SIGTSTP SIGTERM

err=0

# This is to evade any race conditions with the display buffer that cuts off
# text. See votingworks/vx-iso#21.
sleep 1
clear

vx_config_tarball_path="/vx_config.tar.gz"

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

function disk_select() {
    unset _diskname
    unset _datadisk
    
    items=("$@")
    prompt="${items[0]}"
    size="${items[1]}"
    ignore=("${items[@]:2}")

    if [[ -n $size ]]; then
	# Ideally, we exclude mmc drives
        readarray disks < <(lsblk -x SIZE -nblo NAME,SIZE,TYPE | grep "disk" | grep -v mmc | grep -v sd[a-z] | awk -v var="$_size" '$2 > var {print $1,$2}')

	# If no appropriate drives were found, remove the mmc restriction
	if [[ ${#disks[@]} -eq 0 ]]; then
          readarray disks < <(lsblk -x SIZE -nblo NAME,SIZE,TYPE | grep "disk" | grep -v sd[a-z] | awk -v var="$_size" '$2 > var {print $1,$2}')
	fi

        # This dumps the newlines at the end of the entries in the lsblk table
        disks=("${disks[@]//$'\n'/}")
        fixed_disks=()
        just_disks=()

        for value in "${disks[@]}"; do
            name=$(echo "$value" | cut -d ' ' -f 1)
            size=$(echo "$value" | cut -d ' ' -f 2 | numfmt --to=iec)


            if [[ -n ${ignore[0]} ]]; then
                flag=false
                for i in "${ignore[@]}"; do
                    if [[ "$name" == "$i" ]]; then
                        flag=true
                        break
                    fi
                done
                if [[ $flag == true ]]; then
                    continue
                fi
            fi

            if [[ "$_datadisk" != *"$name"* ]]; then
                fixed_disks+=("$name $size")
                just_disks+=("$name")
            fi

        done
        disks=("${just_disks[@]}")
    else
        readarray disks < <(lsblk -x SIZE -nblo NAME,LABEL,SIZE,TYPE | grep "disk" | grep -v mmc | grep -v sd[a-z] | awk '{ print $1 }')

	# If no appropriate drives were found, remove the mmc restriction
	if [[ ${#disks[@]} -eq 0 ]]; then
          readarray disks < <(lsblk -x SIZE -nblo NAME,LABEL,SIZE,TYPE | grep "disk" | grep -v sd[a-z] | awk '{ print $1 }')
	fi
        # This dumps the newlines at the end of the entries in the lsblk table
        disks=("${disks[@]//$'\n'/}")

    fi

    while true; do 
        # If there's only one disk, no need for a menu
        if [[ -z ${disks[0]} ]]; then
            echo "There are no compatible disks!"
            err=1
            return 
        elif [[ ${#disks[@]} == 1 ]]; then
            _diskname=${disks[0]}
            _datadisk="/dev/${disks[0]}"
            return
        else
            unset answer
            menu "${disks[@]}" "$prompt" 
            if [[ $err == 1 ]]; then
                echo "Something went wrong. Please try again."
                continue
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
            return
        fi
    done
}

function part_select() {
    unset part
    _prompt=$2
    _diskname=$1
    while true; do
        # Get all the partitions on the selected disk
        readarray parts < <(lsblk -x SIZE -nblo NAME,LABEL,SIZE,TYPE | grep "part" | grep "$_diskname" | awk '{ print $1 }')
        parts=("${parts[@]//$'\n'/}")

        # if there's only one partition, no need for a menu
        if [[ ${#parts[@]} == 1 ]]; then
            part=${parts[0]}
            return
        else
            unset answer
            menu "${parts[@]}" "$_prompt"
            if [[ $err == 1 ]]; then
                echo "Something went wrong. Please try again."
                err=1
                return
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
            return
        fi
        break
    done
}

function detect_existing_vx_config() {

  vg=$(vgscan | sed -s 's/.*"\(.*\)".*/\1/g')

  if [[ -n $vg && $vg == "Vx-vg" ]]; then

    vx_config_mnt="/tmp/vx_config_mnt"
    vx_root_mnt="/tmp/vx_root_mnt"
    mkdir -p $vx_config_mnt
    mkdir -p $vx_root_mnt

    # Activate the volume group
    vgchange -ay $vg
    
    # Find the encrypted volume
    dir=$(find "/dev/$vg" -name "var_encrypted")

    # Open the encrypted volume
    (echo "" | cryptsetup open $dir var_decrypted) || (echo "insecure" | cryptsetup open $dir var_decrypted)

    mount /dev/mapper/var_decrypted $vx_config_mnt
    mount /dev/mapper/Vx--vg-root $vx_root_mnt

    if ! grep 'luks,tpm2-device=auto' ${vx_root_mnt}/etc/crypttab > /dev/null; then
      previous_secure_boot_state=0
    else
      previous_secure_boot_state=1
    fi

    if [ -d "${vx_config_mnt}/vx/config" ]; then
      previous_machine_type=$(cat ${vx_config_mnt}/vx/config/machine-type)
      previous_machine_id=$(cat ${vx_config_mnt}/vx/config/machine-id)
      tar --exclude="${vx_config_mnt}/vx/config/app-flags" -czvf ${vx_config_tarball_path} ${vx_config_mnt}/vx/config
    fi

    previous_qa_state=$(cat ${vx_config_mnt}/vx/config/is-qa-image)
    previous_prod_cert_hash=$(sha256sum ${vx_root_mnt}/vx/code/vxsuite/libs/auth/certs/prod/vx-cert-authority-cert.pem | cut -d' ' -f1)

    umount $vx_config_mnt
    umount $vx_root_mnt
    rm -rf $vx_config_mnt
    rm -rf $vx_root_mnt

    # Close the encrypted volume
    cryptsetup close var_decrypted

    # Deactivate the volume group
    vgchange -an Vx-vg

    clear
  fi
}

function restore_vx_config() {

  vg=$(vgscan | sed -s 's/.*"\(.*\)".*/\1/g')

  if [[ -n $vg && $vg == "Vx-vg" ]]; then
    vx_config_mnt="/tmp/vx_config_mnt"
    vx_root_mnt="/tmp/vx_root_mnt"
    mkdir -p $vx_config_mnt
    mkdir -p $vx_root_mnt

    # Activate the volume group
    vgchange -ay $vg

    dir=$(find "/dev/$vg" -name "var_encrypted")
    (echo "" | cryptsetup open $dir var_decrypted) || (echo "insecure" | cryptsetup open $dir var_decrypted)

    mount /dev/mapper/var_decrypted $vx_config_mnt

    # We have to do this to ensure the tar command does not change
    # any contents on the root partition, even though all we copy are symlinks
    mount -o ro /dev/mapper/Vx--vg-root $vx_root_mnt

    if ! grep 'luks,tpm2-device=auto' ${vx_root_mnt}/etc/crypttab > /dev/null; then
      new_secure_boot_state=0
    else
      new_secure_boot_state=1
    fi

    new_machine_type=$(cat ${vx_config_mnt}/vx/config/machine-type)
    new_qa_state=$(cat ${vx_config_mnt}/vx/config/is-qa-image)
    new_prod_cert_hash=$(sha256sum ${vx_root_mnt}/vx/code/vxsuite/libs/auth/certs/prod/vx-cert-authority-cert.pem | cut -d' ' -f1)

    # Default to running the config wizard
    # Note: This could override the configuration of an image that
    # did not set this flag as part of setup-machine/lockdown
    touch "${vx_config_mnt}/vx/config/RUN_BASIC_CONFIGURATION_ON_NEXT_BOOT"

    if [[ $previous_secure_boot_state != $new_secure_boot_state ]]; then
      if [[ $DEBUG == 1 ]]; then echo "Secure Boot state does not match"; fi
    elif [[ $previous_machine_type != $new_machine_type ]]; then
      if [[ $DEBUG == 1 ]]; then echo "Machine Type does not match"; fi
    elif [[ $previous_machine_id == "0000" ]]; then
      if [[ $DEBUG == 1 ]]; then echo "Machine ID is the default"; fi
    elif [[ $previous_qa_state != $new_qa_state ]]; then
      if [[ $DEBUG == 1 ]]; then echo "QA Image state does not match"; fi
    elif [[ $previous_prod_cert_hash != $new_prod_cert_hash ]]; then
      if [[ $DEBUG == 1 ]]; then echo "Prod Cert state does not match"; fi
    else
      if [[ -d "${vx_config_mnt}/vx/config" && -f "${vx_config_tarball_path}" ]]; then
        tar --extract --file=${vx_config_tarball_path} --gzip --verbose --keep-directory-symlink -C /

	# Since we're bypassing the config wizard, need to run
	# the fipsinstall step on first boot
        touch "${vx_config_mnt}/vx/config/RUN_FIPS_INSTALL"
	chmod 777 "${vx_config_mnt}/vx/config/RUN_FIPS_INSTALL"

	# Don't run basic config wizard since the config was persisted
        rm -f "${vx_config_mnt}/vx/config/RUN_BASIC_CONFIGURATION_ON_NEXT_BOOT" > /dev/null 2>&1
      fi
    fi

    # Create a flag file to automatically expand the var partition
    # on the newly flashed image first boot, regardless of config transfer
    touch ${vx_config_mnt}/vx/config/EXPAND_VAR

    umount $vx_config_mnt
    rm -rf $vx_config_mnt

    umount $vx_root_mnt
    rm -rf $vx_root_mnt

    cryptsetup close var_decrypted
    vgchange -an $vg
    clear
  fi
}

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
                        echo "Continue without installing keys?" 
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
            # shellcheck disable=SC2210
            chattr -i /sys/firmware/efi/efivars/db* 2&>1 /dev/null  
            # shellcheck disable=SC2210
            chattr -i /sys/firmware/efi/efivars/KEK* 2&>1 /dev/null 
            # shellcheck disable=SC2210
            chattr -i /sys/firmware/efi/efivars/PK* 2&>1 /dev/null 

            keys=$(lsblk -x SIZE -nblo NAME,LABEL,SIZE,TYPE | grep -iF "Keys" | awk '{ print $1 }')

            if [[ -z $keys ]]; then
                disk_select "Which disk contains the keys to install?"
                
                if [[ $err == 1 ]]; then
                    echo "Could not select a disk with keys. Not installing keys."
                    return
                else
                    part_select "$_diskname" "Which partition contains the keys?" 

                    if [[ $err == 1 ]]; then
                        echo "Could not select a partition with keys. Not installing keys."
                        return
                    fi

                    keys="${part}"
                fi
	    else
		echo "Found Keys partition automatically."
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
                echo "Writing keys succeeded! Press Return to continue."
		read -r
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
    disk_select "Which disk contains the image to install?"
    if [[ $err == 1 ]]; then
        echo "Disk selection failed. Could not select an image to install. Exiting..."
        exit
    fi

    part_select "$_diskname" "Which partition contains the image?"
    if [[ $err == 1 ]]; then
        echo "Partition selection failed. Could not select an image to install. Exiting..."
        exit
    fi

    mount "/dev/${part}" /mnt
fi

clear
ignore=()
if [[ -n $data ]]; then 
    echo "Found data partition ${_datadisk} and mounted on /mnt"
    # cut off the partition number
    ignore+=("${_datadisk::-1}")
else
    echo "Mounted data disk ${part} on /mnt"
    ignore+=("${_diskname}")
fi

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
        _hashash=1
    fi
done

if [[ -z ${_images[0]} ]]; then
  echo "Found no image(s) to install. Exiting..."
  exit
fi

unset answer
if [[ ${#_images[@]} > 1 ]]; then
  echo "Found the following images that might work."
  menu "${_images[@]}" "Please select an image to install" 
  if [[ $err == 1 ]]; then
    echo "Something went wrong, please try again."
    exit
  fi
else
  echo "Only one image (${_images[-1]}) was found. It will be automatically selected."
fi

if [[ -n $answer ]]; then
    _toflash=${_images[$answer-1]}
    _extension=${_extensions[$answer-1]}
else
    _toflash=${_images[-1]}
    _extension=${_extensions[-1]}
fi

if [[ $_extension == "lz4" ]]; then
    _compression="lz4"
elif [[ $_extension == "gz" ]]; then
    _compression="gzip"
fi

sleep 3
clear

# We used to parse the image filename for disk space, but it's better
# to inspect the image and calculate the size dynamically
# We dump the boot header, which should contain the sector count we need
# If it doesn't, we just default to 64G. The progress bar will be off, but
# it's not a situation that blocks installing the image.
if [[ -z $_finalsize ]]; then
    lz4cat "$_path/$_toflash" 2>/dev/null | dd of=/tmp/boot_header bs=1M count=1
    sectors=$(file /tmp/boot_header | grep -o '[0-9]\+ sectors' | cut -d' ' -f1)
    if [[ -z $sectors ]]; then
      echo "Could not detect final image size. Defaulting to 64G"
      _finalsize="64G"
    else
      _finalsize=$(( ${sectors} * 512 / 1024 / 1024 / 1024 + 1 ))G
    fi
fi

_disk="/dev/nvme0n1"

# Get our image size in raw bytes
_size=$(numfmt --from=iec "${_finalsize}")

clear
disk_select "Which disk would you like to install to?" "$_size" "${ignore[@]}"

if [[ $err == 1 ]]; then
    echo "No disks were big enough for the image! Exiting..."
    exit
fi

vxdev=0
if echo "$_toflash" | grep -iF "vxdev"; then
    vxdev=1
fi

echo "Installing image" 
echo "$_path/$_toflash"
echo "to disk"
echo "$_datadisk"
echo ""
echo "The install will automatically begin in 10 seconds, unless you choose not to continue."
echo ""
echo "Continue? [y/N]"

read -t 10 -r flash_answer
flash_answer="${flash_answer:-y}"

if [[ $flash_answer != 'y' && $flash_answer != 'Y' ]]; then
    exit
fi

# If the size of the image is decimal, chop off the decimal point and after so
# pv doesn't choke on it. This is fine, since pv is only using the size to
# compute status percentages and will still push the whole file to the disk.
statussize="$(echo "$_finalsize" | cut -d '.' -f 1)"
if ! (echo "$statussize" | grep -qo "G"); then
    statussize="${statussize}G"
fi 

detect_existing_vx_config

$_compression -c -d $_path/"$_toflash" | pv -s "${statussize}" > "$_datadisk"

sleep 3
if [ $_hashash == 1 ]; then 
    echo "Now checking that the write was successful."
    echo "The hash should be:"
    cat "${_path}/${_toflash}.sha256sum"

    echo "Computing hash..."
    head -c $_finalsize "$_datadisk" | pv -s "${statussize}" | sha256sum
fi

umount /mnt

# Assumptions are made about our datadisk
# partition "1" is the boot partition
# partition "3" is the LVM partition
datadisk_suffix=$(echo $_datadisk | cut -d'/' -f3)
flashed_root_partition=$(lsblk -l | grep $datadisk_suffix | grep part | awk '{print $1}' | grep '1$')

# Determine if this is a signed image or not
is_signed_image=0
mount "/dev/${flashed_root_partition}" /mnt
sleep 3
efi_loader="\\EFI\\debian\\shimx64.efi"
if [[ -f "/mnt/EFI/debian/VxLinux-signed.efi" ]]; then
  efi_loader="\\EFI\\debian\\VxLinux-signed.efi"
  is_signed_image=1
fi
umount /mnt

restore_vx_config

# Get the current set of boot entries
efibootmgr -v | grep '/File' | grep -i '\\EFI\\debian' > /tmp/current_boot

boot_label=$(basename ${_toflash%%.img.*})
install_date=$(date +%Y%m%d)
# If we're on a surface or a VxDev device, we don't do ESI. 
if [[ $_surface == 1 || $vxdev == 1 ]]; then
    echo "Creating a boot entry for Surface Go or VxDev image..."
    efibootmgr \
        --create \
        --disk "$_datadisk" \
        --part 1 \
        --label "$boot_label - Installed $install_date" \
        --loader "\\EFI\\debian\\shimx64.efi" \
        --quiet
else
    echo "Creating a boot entry for VotingWorks $boot_label image..."
    efibootmgr \
        --create \
        --disk "$_datadisk" \
        --part 1 \
        --label "$boot_label - Installed $install_date" \
        --loader "$efi_loader" \
        --quiet
fi

# Get the new set of boot entries
efibootmgr -v | grep '/File' | grep -i '\\EFI\\debian' > /tmp/new_boot

new_entry=`diff /tmp/current_boot /tmp/new_boot | grep 'Boot' | cut -d' ' -f2 | cut -d'*' -f1 | sed -e 's/Boot//'`

# Get potential USB entries, exclude potential network devices
usb_entries=$(efibootmgr -v | grep 'USB' | grep -vi network | cut -d' ' -f1 | sed -e s/\*// | sed -e s/Boot// | paste -d, -s) 

# Update the boot order
# This consists of deleting old entries found in /tmp/current_boot
# then setting the new boot order to usb entries,
# followed by the new entry
echo "Deleting old boot entries..."
for old_entry in $(cat /tmp/current_boot | cut -d' ' -f1 | sed -e s/\*// | sed -e s/Boot//)
do
  efibootmgr --delete-bootnum --bootnum $old_entry > /dev/null 2>&1
done

# Update the boot order
if [[ -z $usb_entries ]]; then
  echo "No USB boot entry/entries detected."
else
  echo "Modifying boot order..."
  efibootmgr -o ${usb_entries},${new_entry} > /dev/null 2>&1
fi

# Force an initial boot to the newly created entry, just in case the
# USB is not removed.
# NOTE: This is a one time change that will not affect the stored boot order
efibootmgr -n ${new_entry} > /dev/null 2>&1

clear
echo "The install was successful!"
echo ""
echo "Be sure to remove the vx-iso USB. Press Return/Enter to reboot."
echo "(The system will automatically reboot in 10 seconds.)"
read -t 10 -r
echo "Rebooting..."

systemctl reboot 
