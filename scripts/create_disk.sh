#!/bin/bash

set -e

DISK=kernel_disk.img
SIZE=10G

echo "💾 Creating sparse $SIZE disk image..."
dd if=/dev/zero of=$DISK bs=1M count=0 seek=10240

echo "🔁 Attaching to loop device..."
LOOPDEV=$(sudo losetup --find --show "$DISK")
echo "→ Using loop device: $LOOPDEV"

echo "📐 Partitioning the disk..."
sudo parted -s "$LOOPDEV" mklabel msdos
sudo parted -s "$LOOPDEV" mkpart primary ext2 1MiB 513MiB      # /boot
sudo parted -s "$LOOPDEV" mkpart primary ext4 513MiB 8705MiB   # /
sudo parted -s "$LOOPDEV" mkpart primary linux-swap 8705MiB 100%

echo "📡 Refreshing partition table..."
sudo partprobe "$LOOPDEV"

BOOT_PART=${LOOPDEV}p1
ROOT_PART=${LOOPDEV}p2
SWAP_PART=${LOOPDEV}p3

echo "🧼 Formatting partitions..."
sudo mkfs.ext2 "$BOOT_PART"
sudo mkfs.ext4 "$ROOT_PART"
sudo mkswap "$SWAP_PART"

echo "✅ Partitioning complete!"

# echo "🔗 Mounting partitions..."

