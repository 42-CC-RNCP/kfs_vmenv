#!/tools/bin/bash
set -e

echo "🔧 Fixing LFS toolchain..."

# Detect if we're inside chroot: if /tools exists and LFS is not needed
if [[ -z "$LFS_TGT" ]]; then
  echo "❌ \$LFS_TGT not set. Aborting."
  exit 1
fi

# Use absolute paths (because we're inside chroot)
mkdir -pv /usr/lib
mkdir -pv /lib64

echo "🔗 Creating symlinks for crt*.o files..."
for f in crt1.o crti.o crtn.o; do
  src="/tools/lib/$f"
  dst="/usr/lib/$f"
  if [[ -e "$src" ]]; then
    if [[ ! -e "$dst" ]]; then
      ln -sv "$src" "$dst" || true
    elif [[ "$(readlink -f "$dst")" != "$(readlink -f "$src")" ]]; then
      echo "⚠️  $dst exists but points to wrong target!"
    else
      echo "✅  $dst already correctly linked."
    fi
  fi
done

echo "🔗 Linking libc.so and libc_nonshared.a..."
[ -e "/tools/lib/libc.so" ] && ln -svf "/tools/lib/libc.so"         "/usr/lib/libc.so"
[ -e "/tools/lib/libc_nonshared.a" ] && ln -svf "/tools/lib/libc_nonshared.a" "/usr/lib/libc_nonshared.a"

echo "🔗 Linking dynamic linker for x86_64..."
[ -e "/tools/lib/ld-linux-x86-64.so.2" ] && ln -sfv /tools/lib/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2

echo "🧠 Rewriting GCC specs to remove /tools references..."
GCC_BIN="/tools/bin/${LFS_TGT}-gcc"
SPECS=$(dirname $("$GCC_BIN" -print-libgcc-file-name))/specs
"$GCC_BIN" -dumpspecs | sed 's@/tools@@g' > "$SPECS"

echo "🧪 Running sanity check..."
cd /tmp
echo 'int main(){}' > dummy.c
"$GCC_BIN" dummy.c -o dummy
if readelf -l dummy | grep -q '/tools'; then
  echo "❌ Toolchain still points to /tools – something is wrong!"
  rm -f dummy.c dummy
  exit 1
fi
rm -f dummy.c dummy

echo "✅ Toolchain fixed and working!"
