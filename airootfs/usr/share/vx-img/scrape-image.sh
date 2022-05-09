#!/bin/bash

_disk="/dev/nvme0n1"
_diskname=""

clear
echo "Found the following disks to scrape:"
while true; do

    # Get a list of all available disks large enough to take our image, sorted by size
    readarray diskinfo < <(lsblk -x SIZE -nlo NAME,SIZE,TYPE | grep "disk" | awk '{ print $1,$2 }')
    
    disks=()
    sizes=()
    i=1
    for di in "${diskinfo[@]}"; do
        disk=$(echo "$di" | cut -d ' ' -f 1)
        size=$(echo "$di" | cut -d ' ' -f 2)
        echo "$i. /dev/$disk $size"
        ((i+=1))
        disks+=("$disk")
        sizes+=("$size")
    done
    

    echo "Which disk would you like to scrape? Default: /dev/${disks[-1]}:" 
    read -r answer
    if [[ -n $answer ]]; then
        selected=${disks[answer-1]}

        if [[ -z $selected ]]; then
            echo "Invalid selection, starting over"
            continue
        fi
        _disk="/dev/$selected"
        _diskname=$selected
    else
        _disk="/dev/${disks[-1]}"
        _diskname=${disks[-1]}
    fi
    break
done    

clear

while true; do 
    i=1
    for disk in "${disks[@]}"; do
        echo "$i. /dev/$disk"
        ((i+=1))
    done
    echo "Where should I put the data?" 
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

# TODO do we want be able to select the partition?
mount "${_datadisk}3" /mnt

clear
echo "Mounted data disk ${_datadisk} on /mnt"


echo "Please enter a file name, without extension, for the scraped image:"
read -r _filename

_path="/mnt"


_date=$(date -I'seconds')
_size=$(lsblk -nlo NAME,TYPE,SIZE | grep "disk" | grep "${_diskname}" | awk '{print $3}')
_fullname="/mnt/${_size}-${_date}-${_filename}"
    
clear
echo "Scraping ${_size} bytes off of ${_disk}, to ${_fullname}.gz. This will take a few minutes. Continue? [Y/n]"
read -r choice

if [[ $choice != "Y" && $choice != "y" && -n $choice ]]; then
    echo "Exiting..."
    exit
fi

pv "${_disk}" | gzip -c > "${_fullname}.gz"
clear
echo "Scrape was successful. Now computing a hash for verification purposes."
pv "${_disk}" | sha256sum -b > "${_fullname}.sha256sum"

clear
echo "Operation was successful. Press any key to shut down in 5 seconds."
read -r
sleep 5
poweroff
