#!/bin/bash

vxiso_tarball=$1

if [[ -z "${vxiso_tarball}" ]]; then
  echo "Usage: $0 /path/to/vxiso.tgz"
  echo "Example: $0 ./vx-iso-unsigned-20250305.tgz"
  exit 1
fi

if [[ ! -f "${vxiso_tarball}" ]]; then
  echo "Error: ${vxiso_tarball} does not exist."
  exit 2
fi

tmp_build_dir="tmp-build-dir"
bundle_dir="${tmp_build_dir}/assets"

if [[ -d "${bundle_dir}" ]]; then
  echo "Removing existing ${bundle_dir}"
  sudo rm -r "${bundle_dir}"
fi

mkdir -p $bundle_dir

tar xfz "${vxiso_tarball}" -C "${bundle_dir}"

exit 0
