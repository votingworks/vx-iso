#!/bin/bash

vxiso_tarball=$1
RELEASE_TYPE=${2:-"field"}

if [[ -z "${vxiso_tarball}" ]]; then
  echo "Usage: $0 /path/to/vxiso.tgz [field|admin|superadmin]"
  echo ""
  echo "Example: $0 ./vx-iso-unsigned-20250305.tgz field"
  exit 1
fi

if [[ ! -f "${vxiso_tarball}" ]]; then
  echo "Error: ${vxiso_tarball} does not exist."
  exit 2
fi

if [[ "${RELEASE_TYPE}" != "field" &&
      "${RELEASE_TYPE}" != "admin" &&
      "${RELEASE_TYPE}" != "superadmin" ]]; then

  echo "Usage: $0 /path/to/vxiso.tgz [field|admin|superadmin]"
  echo ""
  echo "You must specify a valid release type. If none is provided, field will"
  echo "be used by default."
  exit 1
fi

tmp_build_dir="tmp-build-dir"
bundle_dir="${tmp_build_dir}/${RELEASE_TYPE}-assets"

if [[ -d "${bundle_dir}" ]]; then
  echo "Removing existing ${bundle_dir}"
  sudo rm -r "${bundle_dir}"
fi

mkdir -p $bundle_dir

tar xfz "${vxiso_tarball}" -C "${bundle_dir}"

exit 0
