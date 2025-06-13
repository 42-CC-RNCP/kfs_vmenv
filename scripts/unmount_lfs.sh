#!/bin/bash
set -e

if [[ -z "$LFS" ]]; then
  echo "❌ Error: LFS variable is not set."
  exit 1
fi

echo "🔧 Unmounting virtual filesystems from $LFS..."

umount -v $LFS/dev/pts || true
umount -v $LFS/dev     || true
umount -v $LFS/proc    || true
umount -v $LFS/sys     || true
# umount -v $LFS/run     || true

echo "✅ All filesystems unmounted from $LFS"
echo "🔑 Exiting chroot environment."
