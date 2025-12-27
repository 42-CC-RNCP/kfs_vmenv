#!/bin/bash
# scripts/install_rootfs.sh
set -e

echo "📁 Creating rootfs directories in $ROOT_MNT..."
sudo mkdir -p $ROOT_MNT/{bin,sbin,etc,proc,sys,dev,boot,root,tmp}
sudo chmod 1777 $ROOT_MNT/tmp


echo "⬇️ Downloading BusyBox..."
sudo wget -O $ROOT_MNT/bin/busybox "$BUSYBOX_URL"
sudo chmod +x $ROOT_MNT/bin/busybox

echo "🔗 Creating symlinks for BusyBox commands..."
cd $ROOT_MNT
for cmd in $(./bin/busybox --list); do
    if [[ "$cmd" == "init" || "$cmd" == "reboot" || "$cmd" == "poweroff" || "$cmd" == "halt" || "$cmd" == "shutdown" || "$cmd" == "getty" ]]; then
        sudo ln -sf ../bin/busybox "sbin/$cmd"
    else
        sudo ln -sf busybox "bin/$cmd"
    fi
done

echo "📁 Copy inittab and fstab..."
sudo cp "$BASEDIR/config/inittab" $ROOT_MNT/etc/inittab
sudo cp "$BASEDIR/config/fstab" $ROOT_MNT/etc/fstab
sudo cp "$BASEDIR/config/hostname" $ROOT_MNT/etc/hostname

lsblk -o NAME,LABEL,FSTYPE,MOUNTPOINT
