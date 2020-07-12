#!/bin/bash

# resize root partition
echo -e "d\n3\nn\np\n3\n\n\nn\nw\n" | fdisk /dev/mmcblk0

# write boot script to run at next boot
cat <<EOF > /etc/bootrunner.d/run/00-resize2fs.sh
resize2fs /dev/mmcblk0p3
EOF

chmod +x /etc/bootrunner.d/run/00-resize2fs.sh
touch /etc/bootrunner.d/reboot
