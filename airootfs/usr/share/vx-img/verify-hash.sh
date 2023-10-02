#!/bin/bash
# Simple placeholder script for verifying the root partition hash
# Will be updated with error checking and any other changes
# once we decide on the final verification approach
echo "Generating hash..."
sha256sum /dev/mapper/Vx--vg-root
echo ""
read -p "Press enter when you are ready to reboot."

reboot
