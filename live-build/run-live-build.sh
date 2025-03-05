#!/bin/bash

mkdir tmp-build-dir
cd tmp-build-dir

../create-base-lb-config.sh

mkdir -p config/hooks/live
cp ../*.hook.* config/hooks/live/

cp ../vxiso.list.chroot config/package-lists/

cp -r ../includes.chroot config/

exit 0
