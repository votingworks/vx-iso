#!/bin/bash

# In an effort to make troubleshooting system/boot issues
# without granting console access possible, this script captures
# information about the system state in a log file. 
# TODOS?
# if it looks like our Vx-vg var_encrypted volume is present
# decrypt it and get more info?
#
# if Vx--vg-root is available, read-only mount and get more info?
#
# add tools to vx-iso for things like lsusb, lspci, etc...?
#

trap '' SIGINT SIGTSTP SIGTERM

log_file="/tmp/system-state.log"
touch $log_file

function write_log() {
  local message="$1"
  
  echo "${message}" >> $log_file
  echo "" >> $log_file
}

function dmidecode_info() {
  write_log "dmidecode start"
  write_log "$(dmidecode -t bios)"
  write_log "$(dmidecode -t system)"
  write_log "$(dmidecode -t processor)"
  write_log "$(dmidecode -t memory)"
  write_log "dmidecode end"
}

function mokutil_info() {
  write_log "mokutil start"
  write_log "sb-state: $(mokutil --sb-state)"
  write_log "pk: $(mokutil --pk | grep Issuer)"
  write_log "kek: $(mokutil --kek | grep Issuer)"
  write_log "db: $(mokutil --db | grep Issuer)"
  write_log "mokutil end"
}

function lsblk_info() {
  write_log "lsblk start"
  write_log "$(lsblk -o NAME,TRAN,MAJ:MIN,RM,SIZE,RO,TYPE,MOUNTPOINTS)"
  write_log "lsblk end"
}

function efibootmgr_info() {
  write_log "efibootmgr start"
  write_log "$(efibootmgr -v)"
  write_log "efibootmgr end"
}

function vxiso_info() {
  write_log "vxiso start"
  write_log "$(grep VERSION /root/.profile | awk '{ print $1, $2 }')"
  write_log "vxiso end"
}

function lvm_info {
  write_log "LVM start"
  write_log "$(pvs)"
  write_log "$(vgs)"
  write_log "$(lvs)"
  write_log "LVM end"
}

dmidecode_info
mokutil_info
lsblk_info
efibootmgr_info
vxiso_info
lvm_info

report_date=$(date +%Y%m%d)
report_name="${report_date}-system-info.log"
data=$(lsblk -nblo NAME,LABEL | grep -F "Data" | awk '{ print $1 }')
mount /dev/$data /mnt
cp $log_file /mnt/${report_name}
umount /mnt

echo "The system info has been written to ${report_name}"
echo "You can find it in the Data directory of this USB drive."
echo "Returning to the vx-iso menu in 5 seconds..."
sleep 5

exit 0
