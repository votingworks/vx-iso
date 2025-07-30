#!/bin/bash
#

# Don't allow ctrl+ commands that could break out to a console
trap '' SIGINT SIGTSTP SIGTERM

timeout=30
dialog_timeout="--timeout ${timeout}"

version="(undefined)"
if [[ "${VERSION}" ]]; then
  version="( ${VERSION} )"
fi
# vx-iso functionality that should always be present
declare -a BASE_MENU=(
  "1:Install Image (default after ${timeout} seconds):/usr/local/bin/flash-image.sh"
  "2:Compute System Hash:/usr/local/bin/compute-system-hash.sh"
  "3:Shutdown:systemctl poweroff"
)

# TODO: rethink this since it's only here for [super]admin cases?
# for [super]admin cases, don't have a default timeout
if [[ "${RELEASE_TYPE}" == "admin" || "${RELEASE_TYPE}" == "superadmin" ]]; then
  dialog_timeout=""
  BASE_MENU[0]="1:Install Image:/usr/local/bin/flash-image.sh"
fi

# additional vx-iso functionality for internal/admin use
declare -a ADMIN_MENU=(
  "4:Delete Boot Entries:/usr/local/bin/delete-boot-entries.sh"
  "5:Reboot to BIOS:systemctl reboot --firmware"
  "6:Zero out EMMC disk:/usr/local/bin/zero-emmc.sh"
)

# admin functionality that should be reserved for superusers
declare -a SUPER_ADMIN_MENU=(
  "7:Open Console:exit 0"
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

  declare -a CURRENT_MENU=()
  
  # always include base menu items
  CURRENT_MENU+=("${BASE_MENU[@]}")
  
  # add admin items if building an admin release
  if [[ "${RELEASE_TYPE}" == "admin" ]]; then
    CURRENT_MENU+=("${ADMIN_MENU[@]}")
  fi
  
  # add super admin items if building a super admin release
  if [[ "${RELEASE_TYPE}" == "superadmin" ]]; then
    CURRENT_MENU+=("${ADMIN_MENU[@]}")
    CURRENT_MENU+=("${SUPER_ADMIN_MENU[@]}")
  fi

  # build dialog arguments
  readarray -t dialog_args < <(build_dialog_args CURRENT_MENU)
  
  # calculate menu height based on number of items
  num_items=$((${#dialog_args[@]} / 2))
  menu_height=$((num_items + 8))
  
  # the dialog command provides a timeout option that is ... not great
  #
  # rather than auto selecting an item, it causes the dialog
  # command to exit, setting the exit value equal to DIALOG_TIMEOUT
  # we use that value to capture that a timeout has been met
  # and automatically set the choice
  # if the dialog is returned to during the same session,
  # the timeout is removed, assuming the user has a keyboard
  # and is unlikely to want an automatic selection
  choice=$(DIALOG_TIMEOUT=5 dialog ${dialog_timeout} --clear --title "VX-ISO Menu ${version}" \
    --menu "Please select an option: " $menu_height 50 $num_items \
    "${dialog_args[@]}" \
    2>&1 >/dev/tty)
  rc=$?
  
  clear

  # dialog command exceeded $timeout timeout value
  # set the choice to 1 from BASE_MENU
  if [[ "${rc}" == "5" ]]; then
    choice="1"
  fi
  
  # no more dialog timeouts after the initial
  dialog_timeout=""

  # update the text of the default selection
  BASE_MENU[0]="1:Install Image:/usr/local/bin/flash-image.sh"

  # execute the selected action
  execute_action "$choice" CURRENT_MENU

done
