#!/bin/bash

mkdir tmp-build-dir
cd tmp-build-dir

# Clean up any previous build
sudo lb clean

../create-base-lb-config.sh

mkdir -p config/hooks/live
cp ../*.hook.* config/hooks/live/

cp ../vxiso.list.chroot config/package-lists/

cp -r ../includes.chroot config/

sudo lb build

exit 0
