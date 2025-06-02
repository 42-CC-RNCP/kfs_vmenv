#!/bin/bash
set -e

IMAGE="kernel_disk.img"
ROOT="/mnt/kernel_disk"

echo "📦 Unmounting all related mountpoints..."
for p in boot root; do
  MOUNTPOINT="$ROOT/$p"
  if mountpoint -q "$MOUNTPOINT"; then
    sudo umount "$MOUNTPOINT"
    echo "✅ Unmounted $MOUNTPOINT"
  fi
done

echo "💤 Disabling swap if active..."
for dev in $(lsblk -ln -o NAME,MOUNTPOINT | grep -E "$ROOT" | awk '{print "/dev/" $1}'); do
  sudo swapoff "$dev" 2>/dev/null || true
done

echo "🔁 Detaching all loop devices linked to $IMAGE..."
LOOPS=$(losetup -j "$IMAGE" | cut -d: -f1)
for loopdev in $LOOPS; do
  echo "  → Detach $loopdev"
  sudo losetup -d "$loopdev" || echo "⚠️  Cannot detach $loopdev"
done

echo "✅ Cleanup complete."
echo "🗑️ Removing $IMAGE..."
if [[ -f "$IMAGE" ]]; then
  rm -f "$IMAGE"
  echo "✅ Removed $IMAGE"
else
  echo "⚠️ $IMAGE not found, skipping removal."
fi
echo "🎉 Cleanup finished successfully!"
