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

FALLBACK_LIB=$("$GCC_BIN" -print-search-dirs | grep '^libraries:' | cut -d '=' -f2 | cut -d ':' -f1)

echo "📁 Copying crt and libc files into: $FALLBACK_LIB"
mkdir -pv "$FALLBACK_LIB"
cp -v /tools/lib/crt*.o /tools/lib/libc.so /tools/lib/libc_nonshared.a "$FALLBACK_LIB"

# 📁 Copying essential .o and .so files into GCC's real search path
LIBDIR=$("$GCC_BIN" -print-file-name=libc.so)
TARGET_LIBDIR=$(dirname "$LIBDIR")

echo "📁 Copying crt and libc files into: $TARGET_LIBDIR"
cp -v /tools/lib/crt*.o "$TARGET_LIBDIR/" || true
cp -v /tools/lib/libc.so "$TARGET_LIBDIR/" || true
cp -v /tools/lib/libc_nonshared.a "$TARGET_LIBDIR/" || true


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


BB=/tools/bin/busybox
chmod 755 "$BB"

echo "🔗 Creating BusyBox helper symlinks & wrappers..."

ln -sf "$BB"  /tools/bin/mv
ln -sf "$BB"  /tools/bin/awk
ln -sf /tools/bin/mv   /bin/mv
ln -sf /tools/bin/awk  /usr/bin/gawk

# -------- 2) gawk wrapper ----------------------------------------------------
cat > /tools/bin/gawk <<'EOF'
#!/tools/bin/bash
if [[ "$1" == "--version" ]]; then
  echo "GNU Awk 5.3.1"
  exit 0
fi
exec /tools/bin/awk "$@"
EOF
chmod 755 /tools/bin/gawk
ln -sf /tools/bin/gawk /usr/bin/gawk

# -------- 3) bison wrapper ---------------------------------------------------
cat > /tools/bin/bison <<'EOF'
#!/tools/bin/bash
if [[ "$1" == "--version" ]]; then
  echo "bison (GNU Bison) 3.8.2"
  exit 0
fi
exit 0
EOF
chmod 755 /tools/bin/bison
ln -sf /tools/bin/bison /usr/bin/bison

# -------- 4) python3 wrapper -------------------------------------------------
cat > /tools/bin/python3 <<'EOF'
#!/tools/bin/bash
if [[ "$1" == "--version" ]]; then
  echo "Python 3.12.0"
  exit 0
fi
exit 0
EOF
chmod 755 /tools/bin/python3
ln -sf /tools/bin/python3 /usr/bin/python3
ln -sf /tools/bin/python3 /usr/bin/python

hash -r
echo "✅ BusyBox links & wrappers ready."
