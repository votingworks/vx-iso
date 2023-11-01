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

The iso file will be created in the `out/` directory. After creating, you can use our Ansible playbooks to automatically prepare each USB drive for use. See below for those steps.

# Setting up USB drives for use with vx-iso and OS images.
## USB Requirements

You should use a Linux OS (Debian 12 is our current standard) for any of the below steps.

You'll need two USB drives: one for the vx-iso created by `mkarchiso` and one for the OS image and optional secure boot keys. We recommend a fast, 64GB+ USB drive for the OS image and keys. 

## Install Ansible
```
sudo ./scripts/install-ansible.sh
```

On Debian 12, you will need to activate the ansible virtualenv:
```
source .virtualenv/ansible/bin/activate
```

You can confirm Ansible is installed by running: `ansible --version`

## Installing the .iso file
1. Ensure your USB drive is inserted
2. Run: 
```sudo ansible-playbook playbooks/vx-iso/flash_vx-iso.yaml -e "iso_file=/path/to/your/iso"```
3. Select your USB drive from the menu
4. Once the .iso file is successfully copied to the USB, you will see a success message.

## Installing the img (and optional keys) file
1. Ensure your fast, 64GB+ USB drive is inserted. NOTE: This should NOT be the same USB used for the .iso file.
2. Run: 
```sudo ansible-playbook playbooks/vx-iso/flash_vx-img.yaml -e "img_file=/path/to/your/img" -e "keys_file=/path/to/your/keys"```
3. Select your USB drive from the menu
4. Wait for the img to be copied. If you provided keys, they will also be extracted onto the drive.
 

