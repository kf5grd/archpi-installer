#!/usr/bin/env bash

# inspired by https://archlinuxarm.org/forum/viewtopic.php?f=31&t=11529#p55623

set -e

if [[ $# -ne 1 ]] ; then
    echo "Usage: $0 </path/to/ArchLinuxARM-rpi.tar.gz>"
    exit 1
fi

DISKFILE="ArchPi-$(date +%Y%m%d-"$(date | sha1sum | cut -b -8)").img"
ARCHFILE="$1"

if [[ -f "${DISKFILE}" ]] ; then
    echo "${DISKFILE}: File already exists"
    exit 1
fi

if [[ "${USER}" != "root" ]] ; then
    echo "Must run as root."
    exit 1
fi

catch_error(){
    local PROCESS="$1"
    local STATUS="$2"

    if [[ "$STATUS" -ne 0 ]] ; then
	echo "An error ocurred while $PROCESS. Exiting..."
	exit "$STATUS"
    fi
}

create_image(){
    # Creates an image file filled with zeros.
    # If called without any arguments then the size is 2048 megabytes
    # Can be passed integer to be used as size in megabytes, e.g. to create 4G file:
    # create_image 4096

    if [[ $# -eq 0 ]] ; then
	local SIZE=2048
    else
	local SIZE="$1"
    fi

    echo -e "\n\n[o] Creating $SIZE image file: ${DISKFILE}"
    dd if=/dev/zero of="${DISKFILE}" bs=1M count="$SIZE"
    catch_error "creating image file" "$?"
}

setup_loop(){
    echo -e "\n\n[o] Setting up loop device"
    LOOPDEV=$(losetup --partscan --find --show "${DISKFILE}")
}

partition_image(){
    # Partitions the disk image.
    # ----
    # As of now, this will create a 100M fat partition, a 10M ext4 partition
    # for bootrunner scripts, and the rest of the image will be filled with an
    # ext4 partition
    echo -e "\n\n[o] Creating partitions"
    echo -e "o\nw" | fdisk -W always "${LOOPDEV}" && \
    echo -e "o\nn\np\n1\n\n+100M\nt\nc\nn\np\n2\n\n+10M\nn\np\n3\n\n\nw" | fdisk -W always "${LOOPDEV}"
    catch_error "creating partitions" "$?"
}

create_fs(){
    echo -e "\n\n[o] Formatting partitions"
    mkfs.vfat "${LOOPDEV}p1" && \
    mkfs.ext4 "${LOOPDEV}p2" && \
    mkfs.ext4 "${LOOPDEV}p3"
    catch_error "creating filesystems" "$?"
}

mount_fs(){
    echo -e "\n\n[o] Mounting partitions"
    mkdir -p boot && \
    mkdir -p root && \
    mount "${LOOPDEV}p1" boot && \
    mount "${LOOPDEV}p3" root && \
    mkdir -p root/etc/bootrunner.d && \
    mount "${LOOPDEV}p2" root/etc/bootrunner.d
    catch_error "mounting filesystems" "$?"
}

install_arch(){
    echo -e "\n\n[o] Installing base OS"
    bsdtar -xpf "${ARCHFILE}" -C root && \
    mv root/boot/* boot && \
    echo -e "# <device>\t<dir>\t<type>\t<options>\t<dump>\t<fsck>" > root/etc/fstab && \
    echo -e "/dev/mmcblk0p3\t/\text4\tdefaults\t0\t0" >> root/etc/fstab && \
    echo -e "/dev/mmcblk0p2\t/etc/bootrunner.d\text4\tdefaults\t0\t0" >> root/etc/fstab && \
    sed -i 's/mmcblk0p2/mmcblk0p3/g' boot/cmdline.txt && \
    sync
    catch_error "installing arch filesystem" "$?"
}

install_scripts(){
    wpa_file="wpa_supplicant.conf"
    wlan0_file="wlan0.network"
    bootrunner_folder="bootrunner.d"
    bootrunner_perm="700"

    echo -e "\n\n[o] Installing scripts"
    # Copy wpa file to boot partition if it exists
    if [ -f "$wpa_file" ]
    then
	cp "$wpa_file" "boot/$wpa_file"
	catch_error "copying $wpa_file to boot partition" "$?"
    fi

    # Copy wlan0.network to boot partition if it exists
    if [ -f "$wlan0_file" ]
    then
	cp "$wlan0_file" "boot/$wlan0_file"
	catch_error "copying $wlan0_file to boot partition" "$?"
    fi

    # If bootrunner.d exists, copy contents to /etc/bootrunner.d
    if [ -d "$bootrunner_folder" ]
    then
	cp -r "$bootrunner_folder"/* "root/etc/$bootrunner_folder" && \
	chmod "$bootrunner_perm" "root/etc/$bootrunner_folder/run"
	catch_error "copying $bootrunner_folder to boot partition" "$?"
    fi

    # Copy get_wpa scripts into place
    cp get_wpa.service root/usr/lib/systemd/system/get_wpa.service && \
    cp get_wpa root/usr/bin/get_wpa && \
    chmod +x root/usr/bin/get_wpa
    catch_error "copying get_wpa scripts into place" "$?"

    # Copy bootrunner scripts into place
    cp bootrunner.service root/usr/lib/systemd/system/bootrunner.service && \
    cp bootrunner root/usr/bin/bootrunner && \
    chmod +x root/usr/bin/bootrunner
    catch_error "copying bootrunner scripts into place" "$?"

    # Enable get_wpa service
    ln -s \
	/usr/lib/systemd/system/get_wpa.service \
	root/etc/systemd/system/multi-user.target.wants/get_wpa.service
    catch_error "enabling the get_wpa service" "$?"

    # Enable bootrunner service
    ln -s \
	/usr/lib/systemd/system/bootrunner.service \
	root/etc/systemd/system/multi-user.target.wants/bootrunner.service
    catch_error "enabling the bootrunner service" "$?"
}

cleanup(){
    echo -e "\n\n[o] Cleaning up"
    umount root/etc/bootrunner.d boot root
    catch_error "unmounting the filesystems" "$?"

    rmdir boot root
    catch_error "removing mount folders" "$?"

    losetup -d "${LOOPDEV}"
    catch_error "deatching loop device" "$?"
}

create_image
setup_loop
partition_image
create_fs
mount_fs
install_arch
install_scripts
cleanup

echo "Done!"
