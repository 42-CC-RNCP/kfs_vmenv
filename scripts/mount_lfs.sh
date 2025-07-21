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
ensure_mount "$BASEDIR/sources" "$LFS/sources"  ""      "bind"

chmod -v a+wt "$LFS/sources"
# ensure_mount tmpfs       "$LFS/run"      tmpfs   "mode=0755,nosuid,nodev"

echo "✅  LFS pseudo-fs mounted."

# ── make sure basic interpreter symlinks exist inside $LFS ────────────────
echo "🔗  Ensuring /bin/bash and /usr/bin/env are available in chroot..."

install -dv "$LFS/bin" "$LFS/usr/bin"

echo "🔧 Fixing tool symlinks in /bin and /usr/bin..."

for tool in bash cat chmod chown cp cut echo env false grep install ln ls mkdir \
             mv pwd rm sed sh stty test touch true uname which head tail basename; do
  for dir in /bin /usr/bin; do
    [ -x /tools/bin/$tool ] && ln -sf /tools/bin/$tool $LFS$dir/$tool
  done
done

echo "✅  Interpreter symlinks created."
