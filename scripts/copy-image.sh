#!/usr/bin/env bash

function usage {
  echo "Usage: $0 -i /path/to/img.lz4 [-k /path/to/keys.tgz] [-h]"
  echo "-i ) Required. This should be the path to an image file."
  echo "-k ) Optional. This should be the path to a tgz containing Secure Boot keys."
}

while getopts "i:k:h" opt; do
  case $opt in
    i)
      img_file=$OPTARG;;
    k)
      keys_file=$OPTARG;;
    h)
      usage
      exit
      ;;
  esac
done

# Check for required img_file option
if [[ -z "$img_file" ]]; then
  usage
  exit 1
fi

# This will be an array of extra variables to pass to Ansible
ansible_extra_vars=()

# Verify img_file exists
if [[ ! -f $img_file ]]; then
  echo "Error: $img_file is not a valid file."
  echo "Please verify the path is correct."
  exit 2
else
  ansible_extra_vars+=(--extra-vars "img_file=${img_file}")
fi

# If the keys_file option was passed, verify the file exists
if [[ ! -z "$keys_file" && ! -f $keys_file ]]; then
  echo "Error: $keys_file is not a valid file."
  echo "Please verify the path is correct."
  exit 3
fi

# If the keys_file option was passed, and the file exists,
# add the option to ansible_extra_vars
if [[ ! -z "$keys_file" && -f $keys_file ]]; then
  ansible_extra_vars+=(--extra-vars "keys_file=${keys_file}")
fi

set -euo pipefail

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

echo "Preparing to copy file(s) to the USB..."
sleep 2
ansible-playbook playbooks/vx-iso/flash_vx-img.yaml ${ansible_extra_vars[@]}

echo "The copy is complete. You can safely eject and remove the USB."

exit 0
