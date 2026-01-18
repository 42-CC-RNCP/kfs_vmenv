#!/bin/bash
set -e

# 6.2: mount points
mkdir -pv "$LFS"/{dev,proc,sys,run,tools,sources,scripts}
mkdir -pv "$LFS/dev/pts"

# custom config mount
mkdir -p "$LFS/host/config"
mount --bind "$BASEDIR/config" "$LFS/host/config"

echo "📦 Downloading kernel $KERNEL_VERSION..."
wget --timestamping \
       --no-hsts \
       --no-adjust-extension \
       --retry-connrefused --timeout=30 \
       --tries=5 --no-check-certificate \
       --directory-prefix="$LFS/sources" \
       "$KERNEL_URL" || { echo "❌ Download failed: $KERNEL_URL"; exit 1; }

# 6.2.1: initial device nodes (on disk)
mknod -m 600 "$LFS/dev/console" c 5 1 || true
mknod -m 666 "$LFS/dev/null"    c 1 3 || true

# 6.2.2: bind-mount /dev
# mountpoint -q "$LFS/dev" || mount -v --bind /dev "$LFS/dev"
# 6.2.2: /dev (recursive bind to include submounts like /dev/shm)
if ! mountpoint -q "$LFS/dev"; then
  mount -v --rbind /dev "$LFS/dev"
fi
mount --make-rslave "$LFS/dev" 2>/dev/null || true

# 6.2.3: virtual kernel file systems
mountpoint -q "$LFS/dev/pts" || mount -vt devpts devpts "$LFS/dev/pts" -o gid=5,mode=620
mountpoint -q "$LFS/proc"    || mount -vt proc  proc  "$LFS/proc"
mountpoint -q "$LFS/sys"     || mount -vt sysfs sysfs "$LFS/sys"
mountpoint -q "$LFS/run"     || mount -vt tmpfs tmpfs "$LFS/run"
mountpoint -q "$LFS/scripts" || mount -v --bind "$BASEDIR/scripts" "$LFS/scripts"

# /dev/shm special case
if [ -h "$LFS/dev/shm" ]; then
  mkdir -pv "$LFS/$(readlink "$LFS/dev/shm")"
fi

echo "✅ LFS pseudo-fs mounted."
echo "✅ check: /dev/shm inside LFS ="
grep " $LFS/dev/shm " /proc/self/mounts || echo "⚠️  $LFS/dev/shm not mounted (check devpts/tmpfs on host)"
