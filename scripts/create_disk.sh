#!/bin/bash
# scripts/create_disk.sh - BIOS/MBR version for x86_64
set -e

echo "🧭 Architecture: x86_64 (BIOS/MBR)"

if [[ -f "$IMAGE" && "${FORCE_RECREATE_IMAGE:-0}" != "1" ]]; then
  echo "⚠️  Image already exists: $IMAGE"
  echo "    Refusing to recreate. Set FORCE_RECREATE_IMAGE=1 if you REALLY want to wipe it."
  exit 0
fi

# === Create Sparse Disk ===
echo "💾 Creating sparse $IMAGE_SIZE image..."
dd if=/dev/zero of="$IMAGE" bs=1M count=0 seek=$(( $(echo "$IMAGE_SIZE" | tr -d 'G') * 1024 ))

# === Attach Loop Device ===
echo "🔁 Attaching loop device..."
LOOPDEV=$(sudo losetup --find --partscan --show "$IMAGE")
echo "→ Using loop device: $LOOPDEV"

# === Partitioning (MBR/BIOS) ===
echo "📐 Partitioning with MBR..."
sudo parted -s "$LOOPDEV" mklabel msdos
sudo parted -s "$LOOPDEV" mkpart primary ext4 1MiB 513MiB
sudo parted -s "$LOOPDEV" mkpart primary ext4 513MiB 18705MiB
sudo parted -s "$LOOPDEV" mkpart primary linux-swap 18705MiB 100%
sudo parted -s "$LOOPDEV" set 1 boot on

# === Refresh partitions ===
echo "📡 Refreshing partition table..."
sudo partprobe "$LOOPDEV"
sleep 2

# === Setup partition variables ===
BOOT_PART="${LOOPDEV}p1"
ROOT_PART="${LOOPDEV}p2"
SWAP_PART="${LOOPDEV}p3"

# === Verify partitions exist ===
if [[ ! -b "$ROOT_PART" ]]; then
  echo "❌ Root partition not found: $ROOT_PART"
  sudo losetup -d "$LOOPDEV"
  exit 1
fi

# === Format partitions ===
echo "🧼 Formatting partitions..."
sudo mkfs.ext4 -L boot "$BOOT_PART"
sudo mkfs.ext4 -L root "$ROOT_PART"
sudo mkswap -L swap "$SWAP_PART"

# === Mount partitions ===
echo "🔗 Mounting partitions..."

# 1. mount root partition
sudo mkdir -p "$ROOT_MNT"
sudo mount "$ROOT_PART" "$ROOT_MNT"

# 2. mount boot partition
sudo mkdir -p "$ROOT_MNT/boot"
sudo mount "$BOOT_PART" "$ROOT_MNT/boot"

# 3. activate swap
sudo swapon "$SWAP_PART"

# === Create basic directory structure ===
echo "📁 Creating basic directory structure..."
sudo mkdir -p "$ROOT_MNT"/{dev,proc,sys,run,tmp}
sudo mkdir -p "$ROOT_MNT"/{bin,sbin,lib,lib64}
sudo mkdir -p "$ROOT_MNT"/{usr,var,etc,home,root}
sudo mkdir -p "$ROOT_MNT"/usr/{bin,sbin,lib,lib64,local,share,include}
sudo mkdir -p "$ROOT_MNT"/var/{log,tmp,cache,lib}

# === Set permissions for tmp directories ===
sudo chmod 1777 "$ROOT_MNT/tmp"
sudo chmod 1777 "$ROOT_MNT/var/tmp"

# === Create disk info file ===
sudo tee "$ROOT_MNT/.disk_info" > /dev/null << EOF
LOOPDEV=$LOOPDEV
BOOT_PART=$BOOT_PART
ROOT_PART=$ROOT_PART
SWAP_PART=$SWAP_PART
ARCH=x86_64
FIRMWARE=BIOS
EOF

# === Show Results ===
echo ""
echo "✅ Disk creation complete!"
echo ""
echo "🔍 Partition layout:"
sudo fdisk -l "$LOOPDEV"

echo ""
echo "🔍 Block devices:"
lsblk "$LOOPDEV"

echo ""
echo "💽 Mounted filesystems:"
df -h | grep "$ROOT_MNT"

echo ""
echo "💤 Swap status:"
swapon --show

echo ""
echo "📋 Summary:"
echo "   Loop device: $LOOPDEV"
echo "   Boot (p1):   $BOOT_PART → $ROOT_MNT/boot (512MB, ext4)"
echo "   Root (p2):   $ROOT_PART → $ROOT_MNT (18GB, ext4)"
echo "   Swap (p3):   $SWAP_PART (active)"
