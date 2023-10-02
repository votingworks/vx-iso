#!/bin/bash
# Provide the ability to delete old/existing boot entries
#

valid_entries='/tmp/valid_entries'
efibootmgr -v | grep 'EFI\\debian' > $valid_entries

if [[ ! -s $valid_entries ]]; then
  echo "There are no valid boot entries to remove."
  sleep 5
  echo "Rebooting..."
  exit 0
  #reboot
fi

while true; do

  echo ""
  echo "The following boot entries are eligible for removal:"
  echo ""
  cat $valid_entries | nl

  echo "Enter the menu number of the boot entry you want to remove:"
  read boot_entry_selection

  if [[ $boot_entry_selection -lt 1 || $boot_entry_selection -gt $(wc -l < $valid_entries) ]]; then
    echo "Invalid entry. Please try again."
    continue
  else
    boot_entry=$(sed -n "${boot_entry_selection}p" $valid_entries)
    echo "Are you sure you want to remove the following EFI boot entry?"
    echo "NOTE: This cannot be undone!"
    echo "$boot_entry"
    echo "Confirm: y/n"
    read confirm

    if [[ $confirm == "Y" || $confirm == "y" ]]; then
      echo "Removing $boot_entry"
      boot_num=$(echo $boot_entry | awk '{print $1}' | sed -e s/Boot// | sed -e s/\*// )
      efibootmgr --delete-bootnum --bootnum $boot_num
    else
      echo "Not removing $boot_entry"
    fi
  fi

  efibootmgr -v | grep 'EFI\\debian' > $valid_entries
  if [[ ! -s $valid_entries ]]; then
    echo "There are no more valid boot entries to remove."
    exit 0
  else
    echo "Would you like to remove another boot entry? y/n"
    read confirm

    if [[ $confirm == "Y" || $confirm == "y" ]]; then
      continue
    else
      exit 0
    fi
  fi

done
