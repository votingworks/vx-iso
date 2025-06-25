#!/bin/bash
#
# Don't allow ctrl+ commands that could break out to a console
trap '' SIGINT SIGTSTP SIGTERM

declare -a BASE_MENU=(
  "1:Install Image:/usr/local/bin/flash-image.sh"
  "2:Compute System Hash:/usr/local/bin/compute-system-hash.sh"
  "3:Shutdown:systemctl poweroff"
)

declare -a ADMIN_MENU=(
  "4:Delete Boot Entries:/usr/local/bin/delete-boot-entries.sh"
  "5:Reboot to BIOS:systemctl reboot --firmware"
  "6:Open Console:exit 0"
  "7:Zero out EMMC disk:/usr/local/bin/zero-emmc.sh"
  "8:Scrape Image(deprecated):/usr/local/bin/scrape-image.sh"
)

# Build dialog menu arguments from menu items
build_dialog_args() {
  local -n items_ref=$1
  local dialog_args=()
  
  for item in "${items_ref[@]}"; do
    IFS=':' read -r num label action <<< "$item"
    dialog_args+=("$num" "$label")
  done
  
  printf '%s\n' "${dialog_args[@]}"
}

# Execute action for selected menu item
execute_action() {
  local selected="$1"
  local -n items_ref=$2
  
  for item in "${items_ref[@]}"; do
    IFS=':' read -r num label action <<< "$item"
    if [[ "$num" == "$selected" ]]; then
      eval "$action"
      return
    fi
  done
  
  echo "Invalid selection: $selected"
}

clear
while true; do
  # Build the complete menu based on environment variables
  declare -a CURRENT_MENU=()
  
  # Always include base menu items
  CURRENT_MENU+=("${BASE_MENU[@]}")
  
  # Add admin items if admin mode is enabled
  if [[ "${ADMIN_RELEASE}" == "1" ]]; then
    CURRENT_MENU+=("${ADMIN_MENU[@]}")
  fi
  
  # Build dialog arguments
  readarray -t dialog_args < <(build_dialog_args CURRENT_MENU)
  
  # Calculate menu height based on number of items
  num_items=$((${#dialog_args[@]} / 2))
  menu_height=$((num_items + 8))
  
  choice=$(dialog --clear --title "VX-ISO Menu" \
    --menu "Please select an option: " $menu_height 50 $num_items \
    "${dialog_args[@]}" \
    2>&1 >/dev/tty)
  
  clear
  
  # Execute the selected action
  execute_action "$choice" CURRENT_MENU
done
