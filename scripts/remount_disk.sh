#!/bin/bash
# scripts/remount_disk.sh
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

ARCH=${ARCH:-$(uname -m)}
IMAGE=${IMAGE:-"kernel_disk.img"}
MNT_ROOT=${MNT_ROOT:-"/mnt/kernel_disk"}
ROOT_MNT=${ROOT_MNT:-"$MNT_ROOT/root"}
BOOT_MNT=${BOOT_MNT:-"$ROOT_MNT/boot"}
EFI_MNT="$BOOT_MNT/efi"

echo -e "${BLUE}🔄 Remounting disk image after reboot...${NC}"

if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}❗ This script must be run as root.${NC}"
  exit 1
fi

if [[ ! -f "$IMAGE" ]]; then
  echo -e "${RED}❌ Image file not found: $IMAGE${NC}"
  exit 1
fi

if mountpoint -q "$ROOT_MNT" 2>/dev/null; then
  echo -e "${YELLOW}⚠️  Root partition already mounted at $ROOT_MNT${NC}"
  echo "Current mounts:"
  df -h | grep "$MNT_ROOT" || true
  echo
  echo -e "${BLUE}Do you want to continue anyway? (y/N)${NC}"
  read -r response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
fi

EXISTING_LOOP=$(losetup -j "$IMAGE" | cut -d: -f1 | head -1)

if [[ -n "$EXISTING_LOOP" ]]; then
  echo -e "${YELLOW}⚠️  Loop device already exists: $EXISTING_LOOP${NC}"
  LOOPDEV="$EXISTING_LOOP"
else
  echo "🔁 Attaching loop device..."
  LOOPDEV=$(losetup --find --partscan --show "$IMAGE")
  echo -e "→ ${GREEN}Loop device created: $LOOPDEV${NC}"
  
  sleep 1
  partprobe "$LOOPDEV" 2>/dev/null || true
  sleep 1
fi

BOOT_PART="${LOOPDEV}p1"
ROOT_PART="${LOOPDEV}p2"
SWAP_PART="${LOOPDEV}p3"

if [[ ! -b "$ROOT_PART" ]]; then
  echo -e "${RED}❌ Root partition not found: $ROOT_PART${NC}"
  echo "Available devices:"
  ls -l "${LOOPDEV}"* || true
  exit 1
fi

echo "📁 Creating mount points..."
mkdir -p "$ROOT_MNT"
if [[ "$ARCH" == "x86_64" ]]; then
  mkdir -p "$BOOT_MNT"
else
  mkdir -p "$EFI_MNT"
fi

if ! mountpoint -q "$ROOT_MNT" 2>/dev/null; then
  echo "🔗 Mounting root partition..."
  mount "$ROOT_PART" "$ROOT_MNT"
else
  echo "✓ Root partition already mounted"
fi

if [[ "$ARCH" == "x86_64" ]]; then
  if ! mountpoint -q "$BOOT_MNT" 2>/dev/null; then
    echo "🔗 Mounting boot partition..."
    mount "$BOOT_PART" "$BOOT_MNT"
  else
    echo "✓ Boot partition already mounted"
  fi
else
  if ! mountpoint -q "$EFI_MNT" 2>/dev/null; then
    echo "🔗 Mounting EFI partition..."
    mount "$BOOT_PART" "$EFI_MNT"
  else
    echo "✓ EFI partition already mounted"
  fi
fi

if swapon -s | grep -q "$(basename "$SWAP_PART")"; then
  echo "✓ Swap already enabled"
else
  echo "💤 Enabling swap..."
  swapon "$SWAP_PART" || echo -e "${YELLOW}⚠️  Swap enable failed (may already be on)${NC}"
fi

echo
echo -e "${GREEN}✅ Remounting complete!${NC}"
echo
echo "🔍 Block devices:"
lsblk -f | grep -E "($(basename "$LOOPDEV")|FSTYPE)" || lsblk -f
echo
echo "💽 Mounted filesystems:"
df -h | grep "$MNT_ROOT" || true
echo
echo "💤 Swap status:"
swapon -s | grep "$(basename "$SWAP_PART")" || swapon -s

echo "$LOOPDEV" > "$ROOT_MNT/.loopdev"

echo -e "${BLUE}You can now chroot into the mounted image using your existing bootstrap.sh script steps.${NC}"
