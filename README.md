# Setting up USB drives for use with vx-iso

## USB and OS Requirements

You should use a Linux OS for the below steps.

We recommend a fast, 64GB+ USB drive to maximize performance.

## Creating a vx-iso USB drive

For these steps, we will assume that your USB is mounted at /dev/sdX.
If your USB mounts to a different device path, be sure to use that. 
You can see where your USB is mounted using `lsblk`.
We also assume that you have downloaded or been provided a vx-iso tarball. 
In this example, we will assume the path is: /tmp/vxiso.tar

If you have not already cloned the repo, you will need to do that.
```
git clone https://github.com/votingworks/vx-iso
```

Within that directory, you will see a `live-build` sub-directory. `cd` into it. You will run all commands from that directory.

The first step is to initialize your USB with the correct partitions and directories.
NOTE: THIS WILL DESTROY ANY EXISTING DATA ON THE USB

(You only need to initialize a USB once. You can skip this step if you have a previously initialized vx-iso USB.)

To initialize your USB, run:
```
sudo ./initialize-usb.sh /dev/sdX
```

Next, you need to extract the vx-iso tarball so the required tools and files can be installed on the USB drive. (You only need to perform this step if you are installing the vx-iso application for the first time or updating to a newer version.) To do that, run:
```
./extract-build-assets.sh /tmp/vxiso.tar
```

The final step is to install vx-iso to the USB. To do that, run:
```
sudo ./install-vx-iso-to-usb.sh /dev/sdX
```

At this point, you will have a USB that can run the vx-iso tool.

Note: You can skip all the previous steps if you have a working vx-iso USB. Those steps are only necessary to install vx-iso for the first time, or if you are upgrading to a newer version.

## Copying VotingWorks application images to the USB

When you attach a vx-iso USB to a Linux system, it should automatically mount two partitions: `Keys` and `Data`. Assuming you have a VotingWorks application image, e.g. `vxscan.img.lz4`, you simply need to copy it to the `Data` partition of your USB. There are many ways to accomplish that, so we provide one example.

Assuming a `Data` partition mounted at: `/media/username/Data`

Assuming an application image at: `/tmp/vxscan.img.lz4`

```
sudo cp /tmp/vxscan.img.lz4 /media/username/Data/ && sudo sync
```

You can now use the vx-iso USB to install this application image on other systems. 

## Copying Secure Boot keys to the USB

Note: This section only applies if you need to install Secure Boot keys to a system.

As mentioned previously, a `Keys` partition should be automatically mounted when you attach the vx-iso USB to your Linux system. Assuming you have the necessary Secure Boot keys, you need to copy them to the `Keys` partition of the USB. 

For VotingWorks employees, please request access to our Secure Boot keys. For everyone else, creating Secure Boot keys is left as an exercise for the reader. 

Since there are many ways to perform the copy, we'll use another simple example.

Assuming a `Keys` partition mounted at: `/media/username/Keys`

Assuming Secure Boot keys in a directory: `/tmp/secure_boot_keys`

```
cp /tmp/secure_boot_keys/* /media/username/Keys/ && sync
```

You can now use the vx-iso USB to install Secure Boot keys to other systems. (Each system will need to be in Setup/Custom mode for Secure Boot. That is outside the scope of this since system BIOSes can vary widely.)

## Creating a new live-build vx-iso tarball

Note: This section only applies to developers interested in building/modifying the vx-iso application. The specifics of using Debian's live-build tool are outside the scope of this README, so the following steps will build the current version of the vx-iso application.

This process should be run on a Debian 12 system.

Install packages, if not already present:
```
apt-get install -y live-build sbsigntool
```

Note: sbsigntool is not necessary if you do not plan to use a Secure Boot enabled version of vx-iso.

The first step is to build the vx-iso application.

From the `live-build` directory, run:
```
./run-live-build.sh
```

This will take awhile to run. After it completes, there will be a new sub-directory: `tmp-build-dir`

To create a vx-iso tarball that can later be installed to a USB, run:
```
./bundle-build-assets.sh
```

This will create a vx-iso tarball in `tmp-build-dir/assets` named `vx-iso-assets.tgz`

NOTE: If you are creating a VotingWorks production release, you need to run:
```
sudo ./lockdown.sh /path/to/vxdbkey.img
```
It will update and sign images as necessary, then recreate the `vx-iso-assets.tgz` tarball.

For either case, you should copy this file elsewhere as the tmp-build-dir/assets directory is regularly deleted as part of running other scripts. We also suggest renaming it with an appropriate naming scheme for your use.

Provide your renamed tarball to anyone who wants to create their own vx-iso USB with your newly built version of the application.
