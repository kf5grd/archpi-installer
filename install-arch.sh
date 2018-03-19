#!/usr/bin/env bash

# script is modified version of script found at:
# https://archlinuxarm.org/forum/viewtopic.php?f=31&t=11529#p55623

set -e

if [[ $# -ne 2 ]] ; then
    echo "Usage: $0 </dev/disk> </path/to/ArchLinuxARM-rpi.tar.gz>"
    exit 1
fi

DISK="$1"
ARCHFILE="$2"

if [[ ! -b "${DISK}" ]] ; then
    echo "Not a block device: ${DISK}"
    exit 1
fi

if [[ "${USER}" != "root" ]] ; then
    echo "Must run as root."
    exit 1
fi

echo "Partitioning disk"
echo -e "o\nw" | fdisk -W always "${DISK}" &> /dev/null
echo -e "o\nn\np\n1\n\n+100M\nt\nc\nn\np\n2\n\n\nw" | fdisk -W always "${DISK}" &> /dev/null

if [[ ! "$?" -eq 0 ]] ; then
    echo "Partitioning disk failed"
    exit 1
fi

echo "Making filesystems"
mkfs.vfat "${DISK}1" &> /dev/null
mkfs.ext4 "${DISK}2" &> /dev/null

echo "Mounting"
mkdir boot
mount "${DISK}1" boot
mkdir root
mount "${DISK}2" root

echo "Installing Arch filesystem"
bsdtar -xpf ${ARCHFILE} -C root &> /dev/null
sync

echo "Moving boot files into place"
mv root/boot/* boot

wpa_file="wpa_supplicant.conf"
wlan0_file="wlan0.network"
if [ -f "$wpa_file" ]
then
    echo "Copying $wpa_file to boot partition"
    cp "$wpa_file" "boot/$wpa_file"
fi

if [ -f "$wlan0_file" ]
then
    echo "Copying $wlan0_file to boot partition"
    cp "$wlan0_file" "boot/$wlan0_file"
fi

echo "Copying scripts into place"
cp get_wpa.service root/usr/lib/systemd/system/get_wpa.service
cp get_wpa root/usr/bin/get_wpa
chmod +x root/usr/bin/get_wpa

echo "Enabling service"
ln -s \
    /usr/lib/systemd/system/get_wpa.service \
    root/etc/systemd/system/multi-user.target.wants/get_wpa.service

echo "Unmounting"
umount boot
umount root

echo "Cleaning up"
rmdir boot
rmdir root
