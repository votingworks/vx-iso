# Setting up USB drives for use with vx-iso and OS images.
## USB Requirements

You should use a Debian 11 or 12 OS for the below steps.

There are two types of USB drives used for installing VotingWorks images.
1. An install drive. 
2. An image (with optional keys) drive.

We recommend a fast, 64GB+ USB drive for the image drive.

## Creating an install drive
1. Ensure your USB drive is inserted and accessible to the VM or system you are using
2. Run: 
```./scripts/create-install-drive.sh /path/to/install.iso```
3. Select your USB drive from the menu
4. Once the .iso file is successfully copied to the USB, you will see a success message.

## Creating an image (with optional secure boot keys) drive
1. Ensure your fast, 64GB+ USB drive is inserted and accessible to the VM or system you are using. NOTE: This should NOT be the same USB used for the .iso file.
2. If you are creating a drive with an image AND secure boot keys: 
```./scripts/copy-image.sh -i /path/to/img.lz4 -k /path/to/keys.tgz```
   
   If you are creating a drive with only an image:
```./scripts/copy-image.sh -i /path/to/img.lz4```

3. Select your USB drive from the menu
4. Wait for the img to be copied. If you provided keys, they will also be extracted onto the drive.
 
# Creating a vx-iso installer image
TODO: This requires a significant update due to implementing secure boot support.

# Creating a vx-iso install USB with support for Keys and Data
TODO: This is an early proof-of-concept, will need more work. It is intended for those more comfortable with manual commands, it doesn't have error checking, could run into issues, etc... Use at your own risk.

IMPORTANT: Please use the right device path. Running this against your local system drive would probably ruin your day if it somehow proceeded. There is only minimal error checking in place for now.

Assuming you already have a working vx-iso (Arch Linux version) USB, attach it to a Linux system (has only been tested on a Debian 12 system so far). Use the `lsblk` command to determine the device path for the USB, e.g. `/dev/sda`

As root (or via sudo), run 
```./scripts/arch_add_partitions.sh /dev/sdX``` 
Replace `/dev/sdX` with the appropriate path to your USB drive. 

After the script completes, your USB drive will have two new partitions: Keys and Data. You can use these just like the current data USB. 

Please note: Current tools (scripts and ansible playbooks) do not yet support this single USB approach. You will need to copy keys / images manually. 
