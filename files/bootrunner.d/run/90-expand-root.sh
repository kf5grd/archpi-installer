#!/bin/bash

# make sure get_wpa service has completed so we don't rip the filesystem
# out while it's in the middle of copying one of its files
WAIT=0
while [ "$(systemctl is-failed get_wpa.service)" != "inactive" ]; do
    WAIT=1
    echo "wait for get_wpa to finish"
    sleep 1
done
test "${WAIT}" == "1" && echo "done waiting for get_wpa to finish"

# resize root partition
echo -e "d\n3\nn\np\n3\n\n\nn\nw\n" | fdisk /dev/mmcblk0

# write boot script to run at next boot
cat <<EOF > /etc/bootrunner.d/run/00-resize2fs.sh
resize2fs /dev/mmcblk0p3
EOF

mv /etc/bootrunner.d/done/00-stop-resolved.sh /etc/bootrunner.d/run/
touch /etc/bootrunner.d/reboot
