#!/usr/bin/env bash

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/installer.iso"
  echo "Example: $0 /home/vx/Downloads/vx-iso-2024.03.20-x86_64-Secure-Boot.iso"
  exit 1
fi

set -euo pipefail

iso_file=$1
debian_major_version=$(cat /etc/debian_version | cut -d'.' -f1)
local_user=`logname`
local_user_home_dir=$( getent passwd "${local_user}" | cut -d: -f6 )

if [[ ! -f .virtualenv/ansible/bin/activate ]]; then
  echo "Installing Ansible..."
  sudo ./scripts/install-ansible.sh
  echo "Ansible installation is complete."
fi

if [[ "$debian_major_version" == "12" ]]; then
  source .virtualenv/ansible/bin/activate
fi

echo "Refreshing sudo credentials. You may be prompted to re-enter your password."
sudo -v
echo "Preparing to copy ${iso_file} to USB..."
sleep 3
ansible-playbook playbooks/vx-iso/flash_vx-iso.yaml -e "iso_file=${iso_file}"

echo "A USB install drive has been created from: ${iso_file}"

exit 0
