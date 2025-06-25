#!/bin/bash

# should be: 0, 1, or 2
# default to 0
# 0 == Customer/Field
# 1 == Admin
# 2 == Super Admin
RELEASE_TYPE=${1:-0}

mkdir tmp-build-dir
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
