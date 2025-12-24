#!/bin/bash
set -eEuo pipefail

IMAGE="${IMAGE:-kernel_disk.img}"
LFS="${LFS:-/mnt/lfs}"
MNT_ROOT="${MNT_ROOT:-/mnt/kernel_disk}"

echo "📦 Cleanup for image: $IMAGE"
echo "📌 LFS=$LFS  MNT_ROOT=$MNT_ROOT"

for mp in \
  "$LFS/dev/pts" \
  "$LFS/dev" \
  "$LFS/proc" \
  "$LFS/sys" \
  "$LFS/run"
do
  if mountpoint -q "$mp"; then
    echo "📦 umount $mp"
    umount "$mp" || umount -l "$mp" || true
  fi
done

mapfile -t LOOPS < <(losetup -j "$IMAGE" | cut -d: -f1 || true)
if [[ ${#LOOPS[@]} -eq 0 ]]; then
  echo "ℹ️ No loop device is using $IMAGE"
else
  for loopdev in "${LOOPS[@]}"; do
    echo "🔎 Handling loop: $loopdev"

    # partitions names e.g. loop0p1 loop0p2...
    mapfile -t PARTS < <(lsblk -ln -o NAME "/dev/$(basename "$loopdev")" | tail -n +2 || true)

    for part in "${PARTS[@]}"; do
      dev="/dev/$part"

      # swapoff
      if grep -q "^$dev " /proc/swaps; then
        echo "💤 swapoff $dev"
        swapoff "$dev" || true
      fi

      # unmount by mountpoints (deepest first)
      mapfile -t MPS < <(findmnt -rn -S "$dev" -o TARGET 2>/dev/null | sort -r || true)
      for mp in "${MPS[@]}"; do
        echo "📦 umount $mp  (src: $dev)"
        umount "$mp" || umount -l "$mp" || true
      done
    done
  done

  for loopdev in "${LOOPS[@]}"; do
    echo "🔁 Detaching $loopdev"
    losetup -d "$loopdev" || {
      echo "⚠️ Detach failed: $loopdev"
      echo "   Remaining mounts for this loop:"
      findmnt -rn -S "/dev/$(basename "$loopdev")"* -o SOURCE,TARGET || true
      exit 1
    }
  done
fi

if [[ -L /tools ]]; then
  tgt="$(readlink -f /tools || true)"
  if [[ "$tgt" == "$(readlink -f "$LFS/tools" 2>/dev/null || echo "")" ]]; then
    echo "🧹 Removing /tools symlink -> $tgt"
    rm -f /tools
  else
    echo "ℹ️ /tools is a symlink but not pointing to $LFS/tools; keep it."
  fi
fi

if [[ "${WIPE_LFS_TOOLS:-0}" == "1" ]]; then
  echo "🧹 WIPE_LFS_TOOLS=1: removing $LFS/tools and stamps"
  rm -rf "$LFS/tools" "$LFS/.kfs/stamps/temp-tools" || true
fi

if [[ -f "$IMAGE" ]]; then
  echo "🗑️ Removing $IMAGE..."
  rm -f "$IMAGE"
  echo "✅ Removed $IMAGE"
fi

echo "🎉 Cleanup finished."
