# vx-iso
This repo contains the configuration necessary for creating an Arch Linux-based install stick that can be used to write verified VotingWorks images to hardware. **NOTE** this must be run on an Arch Linux system, as the `mkarchiso` program depends on having Arch utilities like `pacstrap` available to it. First, install `mkarchiso` and `git`: 

```
sudo pacman -S archiso git
```

Clone the repo and build the image:
```bash
git clone https://github.com/votingworks/vx-iso
cd vx-iso
sudo mkarchiso -v -w /tmp/vxiso-tmp -o out .
```

The iso file will be created in the `out/` directory. After creating, use Ventoy to create a bootable stick.

# Setting up an install stick for use with vx-iso
## Download and use Ventoy
Ventoy is an open-source tool for creating bootable USB stick that can boot multiple `.iso` files. Ventoy also supports UEFI Secure Boot as well as the option to put a data partition on the bootable stick. To set it up, do the following:

1. Download Ventoy from [here](https://github.com/ventoy/Ventoy/releases) or from their [website](https://www.ventoy.net/en/download.html). On Arch Linux-based systems, you can download it from the AUR. 
2. After installation, plug in a fresh USB stick and run Ventoy. **Make sure to run Ventoy as root**, so `sudo VentoyGUI.x86_64`. If running Ventoy as root doesn't work for you, you can also run it as a webserver and use the browser as the GUI: `sudo VentoyWeb.sh` and navigate to `http://localhost:24680`.
3. Make sure the correct device is found by Ventoy.
![image](https://user-images.githubusercontent.com/2686765/158470254-209d9139-f0f9-4939-a6ea-72942538b1de.png)
3. Select Option -> Partition Style -> GPT 
3. Make sure "Secure Boot Support is selected ![image](https://user-images.githubusercontent.com/2686765/158470519-a75f2e22-88fa-4e62-8296-30ea22a98953.png)
4. To create a Data partition, select "Partition Configuration": ![image](https://user-images.githubusercontent.com/2686765/158470639-89b97f27-aef1-422b-a2fb-5fe8bddeca63.png)
5. In the dialog, select "preserve some space at the end of the disk", and type in a number of bytes. I recommend doing 6GB less than the total space on your USB drive, assuming you have at like 16GB total. In this case I am doing 10GB on a 16GB USB drive.  ![image](https://user-images.githubusercontent.com/2686765/158470805-cf0158d6-d60c-41e4-b752-e5723cbe3525.png)
6. With all of that set up, you should see [ -10GB ] (or whatever size you used) next to the "Device" field and there should be a lock icon in the "Ventoy In Package" box: ![image](https://user-images.githubusercontent.com/2686765/158471076-98640960-b33b-4e34-be27-d160d391d53c.png)
7. If that's correct, click "Install" and hit "Okay" on the two dialog boxes that pop up. At the end, you should see a success message, and the "Ventoy in Device" box will be updated:![image](https://user-images.githubusercontent.com/2686765/158471223-7faa162b-9380-4e1e-8880-534253c8efbd.png)

## Format the Data Partition
The space we saved above needs to be formatted into a data partition for storing raw disk images. I usually do this with the GNOME disks utility, which shows something like this right after installing Ventoy: 

![image](https://user-images.githubusercontent.com/2686765/158472339-56536429-2bc7-44db-9f27-fa90b5c61b8b.png)

To create a new partition, select the empty space.
Now click the plus sign in the bottom left hand corner of the disk panel. A "Create Partition" dialog will show up: ![image](https://user-images.githubusercontent.com/2686765/158472489-4c57b447-2a0f-47ce-8a13-625370dbcd10.png)
Leaving the default to use the whole space, the next screen lets you name the partition and set some other configuration. I normally just call the partition "Data", though it doesn't matter.  *IMPORTANT* make sure you set the file system type to Ext4. FAT cannot handle files larger than 4GB, which will not work for us. After the changes, it should look like this: ![image](https://user-images.githubusercontent.com/2686765/158472731-a5ac2b89-4357-4186-a0a6-32cc873168d3.png)
It may take a while for the file system to get created, but afterwards you should see a new "Data" folder mounted and Disks will look like this: ![image](https://user-images.githubusercontent.com/2686765/158473294-ebf739df-4578-4c76-8a40-d86120b39989.png)

## Installing the .iso file
After you have completed the steps above you should see a "Ventoy" and "Data" mounted drive. If you see a "VTOYEFI" that's okay too, as that is the EFI system partition on the USB stick. If any of those aren't mounted by default, mount them using whatever works best for you. The Ventoy folder is where `.iso` files can be dropped for booting. Take the `.iso` we made earlier, or you downloaded from s3, and put it in that folder. Make sure your file system is sync'd before taking out the USB (you can use `sync` on the command line or just eject the USB in the file manager). 

## Installing the disk image
Place any images that should end with `.img.gz` or `.img.lz4` in the "Data" partition on the USB Drive. Again make sure you wait for all the data to sync and properly eject the drive before removing the USB. 

