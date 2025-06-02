#!/bin/bash
set -e

IMAGE="kernel_disk.img"
ROOT="/mnt/kernel_disk"

echo "📦 Unmounting all partitions mounted from $IMAGE..."
LOOPS=$(losetup -j "$IMAGE" | cut -d: -f1)

for loopdev in $LOOPS; do
  for part in $(lsblk -ln -o NAME /dev/$(basename $loopdev) | tail -n +2); do
    dev="/dev/$part"

    if grep -q "$dev" /proc/swaps; then
      echo "💤 swapoff $dev"
      sudo swapoff "$dev" || true
    fi

    if mount | grep -q "$dev"; then
      echo "📦 umount $dev"
      sudo umount "$dev" || true
    fi
  done

  echo "🔁 Detaching $loopdev"
  sudo losetup -d "$loopdev" || echo "⚠️ Cannot detach $loopdev"
done

echo "🗑️ Removing $IMAGE..."
if [[ -f "$IMAGE" ]]; then
  rm -f "$IMAGE"
  echo "✅ Removed $IMAGE"
else
  echo "⚠️ $IMAGE not found, skipping removal."
fi

echo "🎉 Cleanup finished successfully!"
