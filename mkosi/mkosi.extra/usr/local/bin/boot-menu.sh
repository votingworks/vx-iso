#!/bin/bash
#

clear

while true; do
  choice=$( dialog --clear --title "VX-ISO Menu" \
	  --menu "Please select an option: " 15 50 7 \
	  1 "Install Image" \
	  2 "Open Console" \
	  3 "Compute System Hash" \
	  4 "Delete Boot Entries" \
	  5 "Reboot to BIOS" \
	  6 "Shutdown" \
	  7 "Scrape Image" \
	  2>&1 >/dev/tty)

  clear

  case $choice in
	1) 
	   echo "Installing image..."
	   sleep 2
	   /usr/local/bin/flash-image.sh
	   ;;
	2) 
	   echo "Starting console..."
	   sleep 2
	   exit 0
	   ;;
	3) 
	   echo "Calculating Hash..."
	   sleep 2
	   /usr/local/bin/compute-system-hash.sh
	   ;;
	4) 
	   echo "Opening session to delete boot entries..."
	   sleep 2
	   /usr/local/bin/delete-boot-entries.sh
	   ;;
	5) 
	   echo "Rebooting to BIOS..."
	   sleep 2
	   systemctl reboot --firmware
	   ;;
	6) 
	   echo "Shutting down..."
	   sleep 2
	   systemctl poweroff
	   ;;
	7) 
	   echo "Scraping image..."
	   sleep 2
	   /usr/local/bin/scrape-image.sh
	   ;;
  esac
done
