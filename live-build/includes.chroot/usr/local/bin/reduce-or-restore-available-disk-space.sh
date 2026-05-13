#!/bin/bash
# Reduce or restore available disk space for cert testing of low disk space warnings

trap '' SIGINT SIGTSTP SIGTERM

VAR_MOUNT_POINT="/tmp/var"
FILLER_PATH="${VAR_MOUNT_POINT}/vx/data/FILLER"
AVAILABLE_DISK_SPACE_PERCENTAGE_WARNING_THRESHOLD="5"

function open_var_partition() {
  vgchange -ay Vx-vg
  cryptsetup open /dev/mapper/Vx--vg-var_encrypted var_decrypted
}

function mount_var_partition() {
  mkdir -p "${VAR_MOUNT_POINT}"
  mount /dev/mapper/var_decrypted "${VAR_MOUNT_POINT}"
}

function unmount_var_partition() {
  umount "${VAR_MOUNT_POINT}"
}

function close_var_partition() {
  cryptsetup close var_decrypted
  vgchange -an Vx-vg
}

function return_to_main_menu() {
  local exit_code="${1}"
  echo "Returning to main menu in 5 seconds..."
  sleep 5
  exit "${exit_code}"
}

function reduce_total_disk_space_and_write_filler_data() {
  local available_percentage_target="${1}"
  local used_percentage_target="$(( 100 - available_percentage_target ))"

  open_var_partition
  mount_var_partition

  # Remove any existing filler data if present
  rm -f "${FILLER_PATH}"

  # Calculate new (reduced) total disk space as currently used space plus 2GB of buffer
  local used_kb
  read -r used_kb < <(df --output=used "${VAR_MOUNT_POINT}" | tail -1)
  local used_mb="$(( used_kb / 1024 ))"
  local new_total_mb="$(( used_mb + 2 * 1024 ))"

  unmount_var_partition

  # Reduce total disk space
  e2fsck -f /dev/mapper/var_decrypted
  resize2fs /dev/mapper/var_decrypted "${new_total_mb}M"

  mount_var_partition

  # Write enough filler data to reduce available space to available_percentage_target
  local avail_kb
  read -r used_kb avail_kb < <(df --output=used,avail "${VAR_MOUNT_POINT}" | tail -1)
  local total_kb="$(( used_kb + avail_kb ))"
  local filler_kb="$(( (total_kb * used_percentage_target / 100) - used_kb ))"
  local filler_mb="$(( filler_kb / 1024 ))"
  dd if=/dev/zero of="${FILLER_PATH}" bs=1M count="${filler_mb}" status=progress

  unmount_var_partition
  close_var_partition
}

warning_threshold_met="$(( AVAILABLE_DISK_SPACE_PERCENTAGE_WARNING_THRESHOLD - 1 ))"
warning_threshold_nearly_met="$(( AVAILABLE_DISK_SPACE_PERCENTAGE_WARNING_THRESHOLD + 1 ))"

echo "1. Reduce total disk space and write filler data leaving ${warning_threshold_met}% available"
echo "2. Reduce total disk space and write filler data leaving ${warning_threshold_nearly_met}% available"
echo "3. Remove filler data and restore total disk space"
echo "4. Return to main menu"
echo ""
read -r -p "Enter number: " choice

case "${choice}" in
  1)
    echo "Reducing total disk space and writing filler data leaving ${warning_threshold_met}% available"
    reduce_total_disk_space_and_write_filler_data "${warning_threshold_met}"
    ;;
  2)
    echo "Reducing total disk space and writing filler data leaving ${warning_threshold_nearly_met}% available"
    reduce_total_disk_space_and_write_filler_data "${warning_threshold_nearly_met}"
    ;;
  3)
    echo "Removing filler data and restoring total disk space"
    open_var_partition
    mount_var_partition
    rm -f "${FILLER_PATH}"
    rm -f "${VAR_MOUNT_POINT}/opt/EXPAND_VAR_COMPLETE"
    touch "${VAR_MOUNT_POINT}/vx/config/EXPAND_VAR"
    unmount_var_partition
    close_var_partition
    ;;
  4)
    return_to_main_menu 0
    ;;
  *)
    echo "Invalid selection. Please enter 1, 2, 3, or 4."
    return_to_main_menu 1
    ;;
esac

echo "Success!"
return_to_main_menu 0
