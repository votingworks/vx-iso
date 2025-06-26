#!/bin/bash

# should be: 0, 1, or 2
# default to 0
# 0 == Customer/Field
# 1 == Admin
# 2 == Super Admin
RELEASE_TYPE=${1:-"field"}

if [[ "${RELEASE_TYPE}" != "field" &&
      "${RELEASE_TYPE}" != "admin" &&
      "${RELEASE_TYPE}" != "superadmin" ]]; then

  echo "Usage: $0 [field|admin|superadmin]"
  echo ""
  echo "By default, this builds a field release with limited functionality."
  echo "The admin option grants additional functionality without full system access."
  echo "The superadmin option grants full system access. Use with caution."
  exit 1
fi

mkdir -p tmp-build-dir
cd tmp-build-dir

# Clean up any previous build
sudo lb clean

../create-base-lb-config.sh

mkdir -p config/hooks/live
echo "RELEASE_TYPE=${RELEASE_TYPE}" >> config/environment.chroot
cp ../*.hook.* config/hooks/live/

cp ../vxiso.list.chroot config/package-lists/

cp -r ../includes.chroot config/

sudo lb build

exit 0
