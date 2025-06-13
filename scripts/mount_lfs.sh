#!/bin/bash
set -e

# TODO: Should not hardcode LFS path, but use a variable or config file.
LFS=

if [[ -z "$LFS" ]]; then
  echo "❌ Error: LFS is not set."
  exit 1
fi

mount -v --bind /dev $LFS/dev
mount -v --bind /dev/pts $LFS/dev/pts
mount -v -t proc proc $LFS/proc
mount -v -t sysfs sysfs $LFS/sys
# mount -v -t tmpfs tmpfs $LFS/run

echo "✅ LFS mounted successfully."
