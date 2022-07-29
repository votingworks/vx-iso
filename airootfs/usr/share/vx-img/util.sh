#!/bin/bash

# shellcheck disable=SC2003
function int(){ expr 0 + "${1:-}" 2>/dev/null||:; }

function menu() {

    # Due to quirks of how bash passes arrays, all args are one array. The
    # prompt Argument gets put at the end of the array, so we have to take it
    # out. 
    items=("$@")
    prompt="${items[-1]}"

    unset 'items[-1]'

    if [ ${#items[@]} -eq 0 ]; then
        return 1
    fi

    i=1
    for item in "${items[@]}"; do
        echo "$i. $item"
        ((i+=1))
    done

    echo  "$prompt Default: [${items[-1]}]"
    read -r answer
    export answer
    return 0
}

function disk_select() {
    unset _diskname
    unset _datadisk

    prompt=$1
    size=$2

    if [[ -n $size ]]; then
        echo "$size"
        readarray disks < <(lsblk -x SIZE -nblo NAME,SIZE,TYPE | grep "disk" | awk -v var="$size" '$2 > var {print $1,$2}')
        # This dumps the newlines at the end of the entries in the lsblk table
        disks=("${disks[@]//$'\n'/}")
        fixed_disks=()
        just_disks=()
        for value in "${disks[@]}"; do
            name=$(echo "$value" | cut -d ' ' -f 1)
            size=$(echo "$value" | cut -d ' ' -f 2 | numfmt --to=iec)
            if [[ "$_datadisk" != *"$name"* ]]; then
                fixed_disks+=("$name $size")
                just_disks+=("$name")
            fi
        done
        disks=("${just_disks[@]}")
    else
        readarray disks < <(lsblk -x SIZE -nblo NAME,LABEL,SIZE,TYPE | grep "disk" | awk '{ print $1 }')
        # This dumps the newlines at the end of the entries in the lsblk table
        disks=("${disks[@]//$'\n'/}")
    fi

    while true; do 
        # If there's only one disk, no need for a menu
        if [[ -z ${disks[0]} ]]; then
            echo "There are no compatible disks!"
            return 1
        elif [[ ${#disks[@]} == 1 ]]; then
            export _diskname=${disks[0]}
            export _datadisk="/dev/${disks[0]}"
            return 0
        else
            unset answer
            if ! menu "${disks[@]}" "$prompt"; then
                echo "Something went wrong. Please try again."
                continue
            fi

            if [[ -n $answer ]]; then
                idx=$(($(int "$answer") - 1))
                selected="${disks[$idx]}"
                if [[ $idx == " - 1" || -z $selected ]]; then
                    echo "Invalid selection, starting over"
                    sleep 3
                    clear
                    continue
                fi
                export _diskname=$selected
                export _datadisk="/dev/$selected"
            else
                export _diskname=${disks[-1]}
                export _datadisk="/dev/${disks[-1]}"
            fi
            return 0
        fi
    done
}
