#!/bin/bash
set -e

# IMAGE="kernel_IMAGE.img"
# IMAGE_SIZE="10G"
# MNT_ROOT="/mnt/kernel_IMAGE"
# BOOT_MNT="$MNT_ROOT/boot"
# ROOT_MNT="$MNT_ROOT/root"

echo "💾 Creating sparse $IMAGE_SIZE IMAGE image..."
dd if=/dev/zero of="$IMAGE" bs=1M count=0 seek=10240

echo "🔁 Checking for existing loop device..."
EXISTING_LOOP=$(sudo losetup -j "$IMAGE" | cut -d: -f1)

if [ -n "$EXISTING_LOOP" ]; then
    echo "⚠️ Loop device already attached: $EXISTING_LOOP"
    LOOPDEV="$EXISTING_LOOP"
else
    echo "🔁 Attaching new loop device..."
    LOOPDEV=$(sudo losetup --find --show "$IMAGE")
fi

echo "→ Using loop device: $LOOPDEV"

echo "📐 Partitioning the IMAGE..."
sudo parted -s "$LOOPDEV" mklabel msdos
sudo parted -s "$LOOPDEV" mkpart primary ext2 1MiB 513MiB      # /boot
sudo parted -s "$LOOPDEV" mkpart primary ext4 513MiB 8705MiB   # /
sudo parted -s "$LOOPDEV" mkpart primary linux-swap 8705MiB 100%

echo "📡 Refreshing partition table..."
sudo partprobe "$LOOPDEV"

BOOT_PART="${LOOPDEV}p1"
ROOT_PART="${LOOPDEV}p2"
SWAP_PART="${LOOPDEV}p3"

echo "🧼 Formatting partitions..."
sudo mkfs.ext2 -L boot "$BOOT_PART"
sudo mkfs.ext4 -L root "$ROOT_PART"
sudo mkswap -L swap "$SWAP_PART"

echo "✅ Partitioning complete!"

echo "🔗 Mounting partitions..."
sudo mkdir -p "$BOOT_MNT"
sudo mkdir -p "$ROOT_MNT"
sudo mount "$BOOT_PART" "$BOOT_MNT"
sudo mount "$ROOT_PART" "$ROOT_MNT"
sudo swapon "$SWAP_PART"

echo "✅ Partitions mounted!"

echo "📜 Partition details:"
echo
echo "🔍 lsblk -f:"
lsblk -f | grep -E "$(basename "$LOOPDEV")"
echo
echo "💽 df -h:"
df -h | grep "$MNT_ROOT"
echo
echo "💤 swapon -s:"
swapon -s
