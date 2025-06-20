#!/bin/bash
set -e

mount -v --bind /dev $LFS/dev
mount -v --bind /dev/pts $LFS/dev/pts
mount -v -t proc proc $LFS/proc
mount -v -t sysfs sysfs $LFS/sys
# mount -v -t tmpfs tmpfs $LFS/run

echo "✅ LFS mounted successfully."
