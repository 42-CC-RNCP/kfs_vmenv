#!/bin/bash
set -e

ensure_mount () {
  local src=$1 tgt=$2 type=$3 opts=$4
  if ! mountpoint -q "$tgt"; then
    mkdir -p "$tgt"
    mount -v ${type:+-t "$type"} ${opts:+-o "$opts"} "$src" "$tgt"
  fi
}

ensure_mount /dev               "$LFS/dev"      ""      "rbind"
ensure_mount /dev/pts           "$LFS/dev/pts"  ""      "rbind"
ensure_mount proc               "$LFS/proc"     proc    ""
ensure_mount sysfs              "$LFS/sys"      sysfs   ""
ensure_mount "$BASEDIR/scripts" "$LFS/scripts"  ""      "bind"
# ensure_mount tmpfs       "$LFS/run"      tmpfs   "mode=0755,nosuid,nodev"

echo "✅  LFS pseudo-fs mounted."

# ── make sure basic interpreter symlinks exist inside $LFS ────────────────
echo "🔗  Ensuring /bin/bash and /usr/bin/env are available in chroot..."

install -dv "$LFS/bin" "$LFS/usr/bin"

# 1. /bin/bash  →  /tools/bin/bash
if [ ! -e "$LFS/bin/bash" ]; then
  ln -sv /tools/bin/bash "$LFS/bin/bash"
fi

# 2. /usr/bin/env  →  /tools/bin/env
if [ ! -e "$LFS/usr/bin/env" ]; then
  ln -sv /tools/bin/env "$LFS/usr/bin/env"
fi

echo "✅  Interpreter symlinks created."
