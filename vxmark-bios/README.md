# Creating USB drives and .iso files for VSAP BIOS updates

## Requirements

You should use a Linux OS for these steps.

You need to have already extracted the VSAP BIOS zip file on your system. For this example, we will assume the extracted directory path is: /tmp/VSAP-BIOS

## Initializing the USB drive

NOTE: THIS WILL DESTROY ANY EXISTING DATA ON THE USB

To initialize your USB, run:
```
sudo ./initialize-usb.sh /dev/sda
```

## Copy the BIOS to the USB

To copy all BIOS update files to the USB, run:
```
sudo ./copy-bios-to-usb.sh /dev/sda /tmp/VSAP-BIOS
```

This USB drive can now be used to update the VSAP BIOS.
It can also be used to create a separate vxmark-bios-update.iso file to share with others. 

## (Optional) Create an ISO file from the USB

To create a vxmark-bios-update.iso file that can be shared with others, run:
```
sudo ./create-iso-from-usb.sh /dev/sda
```

To create a USB drive from this file (rather than executing the previous steps, run:
```
sudo dd if=/path/to/vxmark-bios-update.iso of=/dev/sda bs=4M
```

