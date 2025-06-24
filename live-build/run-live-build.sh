#!/bin/bash

IS_ADMIN_RELEASE=${1:-0}

mkdir tmp-build-dir
cd tmp-build-dir

# Clean up any previous build
sudo lb clean

../create-base-lb-config.sh

mkdir -p config/hooks/live
echo "IS_ADMIN_RELEASE=${IS_ADMIN_RELEASE}" >> config/environment.chroot
cp ../*.hook.* config/hooks/live/

cp ../vxiso.list.chroot config/package-lists/

cp -r ../includes.chroot config/

sudo lb build

exit 0
