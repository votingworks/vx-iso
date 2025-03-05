TODO: clean this up, proper formatting, etc...

Creating a live-build:
Package Dependencies: apt-get install -y live-build sbsigntool

From vx-iso/live-build:
./run-live-build.sh

After this completes, there will be a new subdir: tmp-build-dir
Remain in vx-iso/live-build dir
To create a vx-iso asset bundle that can later be installed to a USB:
./bundle-build-assets.sh

This will create a tarball in tmp-build-dir/assets named vx-iso-assets.tgz

You should copy this file elsewhere as the tmp-build-dir/assets directory
is deleted as part of multiple scripts.

This is the file needed when creating the USB.

Preparing a USB:
Assuming the USB mounts at /dev/sda for below commands. Use appropriate path.
Assuming vx-iso-assets.tgz located at: /tmp/vx-iso-assets.tgz
From vx-iso/live-build:

sudo ./initialize-usb.sh /dev/sda 
./extract-build-assets.sh /tmp/vx-iso-assets.tgz
sudo ./install-vx-iso-to-usb.sh /dev/sda
