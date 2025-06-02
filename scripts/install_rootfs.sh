#!/bin/bash

set -e

HOST="lyeh"
ROOTFS="/mnt/kernel_disk/root"
BUSYBOX_URL="https://busybox.net/downloads/binaries/1.36.0-defconfig-multiarch/busybox-x86_64"

echo "📁 Creating rootfs directories in $ROOTFS..."
sudo mkdir -p $ROOTFS/{bin,sbin,etc,proc,sys,dev,boot,root,tmp}
sudo chmod 1777 $ROOTFS/tmp


echo "⬇️ Downloading BusyBox..."
sudo wget -O $ROOTFS/bin/busybox "$BUSYBOX_URL"
sudo chmod +x $ROOTFS/bin/busybox

echo "🔗 Creating symlinks for BusyBox commands..."
cd $ROOTFS
for cmd in $(./bin/busybox --list); do
    if [[ "$cmd" == "init" || "$cmd" == "reboot" || "$cmd" == "poweroff" || "$cmd" == "halt" || "$cmd" == "shutdown" || "$cmd" == "getty" ]]; then
        sudo ln -sf ../bin/busybox "sbin/$cmd"
    else
        sudo ln -sf busybox "bin/$cmd"
    fi
done

echo "📁 Copy inittab and fstab..."
sudo cp ../config/inittab $ROOTFS/etc/inittab
sudo cp ../config/fstab $ROOTFS/etc/fstab
sudo cp ../config/hostname $ROOTFS/etc/hostname

lsblk -o NAME,LABEL,FSTYPE,MOUNTPOINT
