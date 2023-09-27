#!/usr/bin/env bash

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/img.lz4"
  exit 1
fi

set -euo pipefail

img_file=$1
debian_major_version=$(cat /etc/debian_version | cut -d'.' -f1)
local_user=`logname`
local_user_home_dir=$( getent passwd "${local_user}" | cut -d: -f6 )

if [[ ! -f .virtualenv/ansible/bin/activate ]]; then
  echo "Installing Ansible..."
  sudo ./scripts/install-ansible.sh online
  echo "Ansible installation is complete."
fi

if [[ "$debian_major_version" == "12" ]]; then
  source .virtualenv/ansible/bin/activate
fi

echo "Preparing to copy ${img_file} to USB..."
sleep 3
ansible-playbook playbooks/vx-iso/flash_vx-img.yaml -e "img_file=${img_file}"

echo "${img_file} has been copied to the USB."

exit 0
