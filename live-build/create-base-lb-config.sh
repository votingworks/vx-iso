#sudo apt-get update
#sudo apt-get install live-build sbsigntool efitools

lb config \
	--architectures amd64 \
	--binary-images iso-hybrid \
	--bootloader grub-efi \
	--uefi-secure-boot enable \
	--distribution bookworm \
	--archive-areas "main contrib non-free-firmware" \
	--bootappend-live "boot=live components" \


#mkdir -p config/hooks/live/
