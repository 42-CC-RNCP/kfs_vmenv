#!/bin/bash
# scripts/create_disk.sh
set -e

ARCH=$(uname -m)

EFI_MNT="$BOOT_MNT/efi"  # Only for ARM64

echo "🧭 Detected architecture: $ARCH"

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

# === Partitioning ===
echo "📐 Partitioning the image..."
if [[ "$ARCH" == "x86_64" ]]; then
  sudo parted -s "$LOOPDEV" mklabel msdos
  sudo parted -s "$LOOPDEV" mkpart primary ext2 1MiB 513MiB
  sudo parted -s "$LOOPDEV" mkpart primary ext4 513MiB 18705MiB
  sudo parted -s "$LOOPDEV" mkpart primary linux-swap 18705MiB 100%
  BOOT_FS="ext2"
  BOOT_LABEL="boot"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
  sudo parted -s "$LOOPDEV" mklabel gpt
  sudo parted -s "$LOOPDEV" mkpart ESP fat32 1MiB 513MiB
  sudo parted -s "$LOOPDEV" set 1 boot on
  sudo parted -s "$LOOPDEV" mkpart primary ext4 513MiB 18705MiB
  sudo parted -s "$LOOPDEV" mkpart primary linux-swap 18705MiB 100%
  BOOT_FS="vfat"
  BOOT_LABEL="EFI"
else
  echo "❌ Unsupported architecture: $ARCH"
  sudo losetup -d "$LOOPDEV"
  exit 1
fi

# === Refresh partitions ===
echo "📡 Refreshing partition table..."
sudo partprobe "$LOOPDEV"

# === Setup partition variables ===
BOOT_PART="${LOOPDEV}p1"
ROOT_PART="${LOOPDEV}p2"
SWAP_PART="${LOOPDEV}p3"

# === Format partitions ===
echo "🧼 Formatting partitions..."
if [[ "$BOOT_FS" == "ext2" ]]; then
  sudo mkfs.ext2 -L "$BOOT_LABEL" "$BOOT_PART"
else
  sudo mkfs.vfat -F32 -n "$BOOT_LABEL" "$BOOT_PART"
fi
sudo mkfs.ext4 -I 256 -L root "$ROOT_PART"
sudo mkswap -L swap "$SWAP_PART"

# === Mount partitions ===
echo "🔗 Mounting partitions..."
sudo mkdir -p "$ROOT_MNT"
sudo mount "$ROOT_PART" "$ROOT_MNT"

if [[ "$ARCH" == "x86_64" ]]; then
  sudo mkdir -p "$BOOT_MNT"
  sudo mount "$BOOT_PART" "$BOOT_MNT"
else
  sudo mkdir -p "$EFI_MNT"
  sudo mount "$BOOT_PART" "$EFI_MNT"
fi

sudo swapon "$SWAP_PART"

# === Show Results ===
echo "✅ Partitioning and mounting complete!"
echo
echo "🔍 lsblk:"
lsblk -f | grep "$(basename "$LOOPDEV")"
echo
echo "💽 df -h:"
df -h | grep "$MNT_ROOT"
echo
echo "💤 swapon -s:"
swapon -s
