#!/bin/bash
set -e

if [[ -z "$LFS" ]]; then
  echo "❌ Error: LFS is not set."
  exit 1
fi

mount -v --bind /dev $LFS/dev
mount -v --bind /dev/pts $LFS/dev/pts
mount -v -t proc proc $LFS/proc
mount -v -t sysfs sysfs $LFS/sys
mount -v -t tmpfs tmpfs $LFS/run

chroot "$LFS" /tools/bin/env -i \
  HOME=/root TERM="$TERM" PS1='(lfs) \u:\w\$ ' \
  PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
  /tools/bin/bash --login +h

echo "🔑 Entered LFS environment. You can now run LFS commands.
To exit, type 'exit' or press Ctrl+D."
