#!/usr/bin/env bash

# script is modified version of script found at:
# https://archlinuxarm.org/forum/viewtopic.php?f=31&t=11529#p55623

set -e

if [[ $# -ne 1 ]] ; then
    echo "Usage: $0 </dev/disk>"
    exit 1
fi

DISK="$1"

if [[ ! -b "${DISK}" ]] ; then
    echo "Not a block device: ${DISK}"
    exit 1
fi

if [[ "${USER}" != "root" ]] ; then
    echo "Must run as root."
    exit 1
fi

echo Mounting
mkdir root
mount "${DISK}2" root

cp get_wpa.service root/usr/lib/systemd/system/get_wpa.service
cp get_wpa root/usr/bin/get_wpa
chmod +x root/usr/bin/get_wpa

ln -s \
    /usr/lib/systemd/system/get_wpa.service \
    root/etc/systemd/system/multi-user.target.wants/get_wpa.service

echo Unmounting
umount root

echo Cleaning up
rmdir root
