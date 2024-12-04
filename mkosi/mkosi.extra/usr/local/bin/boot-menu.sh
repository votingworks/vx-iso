#!/bin/bash
#

clear

while true; do
  choice=$( dialog --clear --title "VX-ISO Menu" \
	  --menu "Please selection an option: " 15 50 5 \
	  1 "Open Console" \
	  2 "Show the date" \
	  3 "Reboot to BIOS" \
	  4 "Shutdown" \
	  5 "Install Image" \
	  2>&1 >/dev/tty)

  clear

  case $choice in
	1) 
	   echo "Starting console..."
	   sleep 2
	   exit 0
	   ;;
	2) 
	   echo "Show the date..."
	   sleep 2
	   date
	   sleep 10
	   ;;
	3) 
	   echo "Rebooting to BIOS..."
	   sleep 2
	   systemctl reboot --firmware
	   ;;
	4) 
	   echo "Shutting down..."
	   sleep 2
	   systemctl poweroff
	   ;;
	5) 
	   echo "Installing image..."
	   sleep 2
	   /usr/local/bin/flash-image.sh
	   ;;
  esac
done
