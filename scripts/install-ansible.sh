#!/usr/bin/env bash

set -euo pipefail

debian_major_version=$(cat /etc/debian_version | cut -d'.' -f1)
system_architecture=$(uname -m)
local_user=`logname`

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

function apt_install ()
{
  if [[ "$debian_major_version" == "12" ]]; then
    local python_packages="python3 python3-pip python3-virtualenv"
  else
    local python_packages="python3.9 python3-pip"
  fi

  apt-get install -y ${python_packages}
}

function pip_install ()
{

  if [[ "$debian_major_version" == "12" ]]; then
    cd ${DIR}/..
    mkdir -p .virtualenv
    cd .virtualenv && virtualenv ansible
    cd ..
    source .virtualenv/ansible/bin/activate
  fi

  pip3 install ansible passlib
}

apt_install
pip_install

echo "Done"
exit 0
