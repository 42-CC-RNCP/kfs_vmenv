#!/bin/bash
set -e

export PATH=/usr/bin:/bin
hash -r

if [[ -z "$LFS" || -z "$LFS_TGT" ]]; then
  echo "❌ Error: LFS or LFS_TGT environment variables are not set."
  echo "Please ensure you have run the init_lfs.sh script first."
  exit 1
fi

cd $LFS/sources

build_binutils_pass1() {
  echo "🔧 Building binutils (pass 1)..."
  echo "📦 Cleaning previous binutils directory if it exists..."
  rm -rf binutils-*/

  tar -xf binutils-*.tar.*z
  cd binutils-*/

  (mkdir -v build ) && cd build
  ../configure --prefix=/tools \
               --with-sysroot=$LFS \
               --target=$LFS_TGT \
               --disable-nls \
               --disable-werror \
               --enable-gprofng=no

  make -j$(nproc)
  make install

  cd ../..
  rm -rf binutils-*/
  echo "✅ binutils (pass 1) done."
}

build_gcc_pass1() {
  echo "🔧 Building gcc (pass 1)..."
  echo "📦 Cleaning previous gcc directory if it exists..."
  rm -rf gcc-*/ > /dev/null
  rm -rf mpfr-*/ gmp-*/ mpc-*/ > /dev/null

  tar -xf gcc-*.tar.*z
  cd gcc-*/

  for dep in mpfr gmp mpc; do
    dep_path=$(find ../ -maxdepth 1 -name "$dep-*.tar.*z" | head -n 1)
    if [[ -z "$dep_path" ]]; then
      echo "❌ Error: Required dependency $dep not found in sources directory."
      exit 1
    fi
    echo "📦 Extracting $dep from $dep_path..."
    tar -xf "$dep_path"
    mv -v "$dep-"* "$dep"
  done

  mkdir -v build && cd build
  ../configure --target=$LFS_TGT \
               --prefix=/tools \
               --with-glibc-version=2.13 \
               --with-sysroot=$LFS \
               --with-newlib \
               --without-headers \
               --enable-initfini-array \
               --disable-nls \
               --disable-shared \
               --disable-multilib \
               --disable-decimal-float \
               --disable-threads \
               --disable-libatomic \
               --disable-libgomp \
               --disable-libquadmath \
               --disable-libssp \
               --disable-libvtv \
               --disable-libstdcxx \
               --enable-languages=c,c++

  make -j$(nproc)
  make install

  cd ../..
  rm -rf gcc-*/
  echo "✅ gcc (pass 1) done."
}

build_linux_headers() {
  echo "🔧 Installing Linux headers (per LFS §5.4)..."

  rm -rf linux-*/
  tar -xf linux-*.tar.*z
  cd linux-*/

  make mrproper
  cp -v "$BASEDIR/config/kernel.config" .config
  make olddefconfig

  rm -fv dest
  make INSTALL_HDR_PATH=dest headers_install

  rm -rf "$LFS/usr/include/linux" "$LFS/usr/include/asm" "$LFS/usr/include/asm-generic"
  mkdir -p "$LFS/usr/include"
  cp -rv dest/include/* "$LFS/usr/include/"

  cd ..
  rm -rf linux-*/
  echo "✅ Linux headers installed to $LFS/usr/include"
}

check_linux_headers() {
  header_folder="$LFS/usr/include/linux"
  if [[ -d "$header_folder" ]]; then
    echo "✅ Linux headers already installed at $header_folder"
  else
    echo "❌ Linux headers not found at $header_folder"
    echo "Please ensure you have run the init_lfs.sh script first."
    exit 1
  fi
}

build_glibc() {
  echo "🔧 Building glibc (LFS ch5)..."
  rm -rf glibc-*/
  tar -xf glibc-*.tar.*z
  cd glibc-*/

  mkdir -v build && cd build
  echo "rootsbindir=/usr/sbin" > configparms

  echo "🔧 Setting up cross-toolchain environment..."
  export CC=/tools/bin/$LFS_TGT-gcc
  export CXX=/tools/bin/$LFS_TGT-g++
  export AR=/tools/bin/$LFS_TGT-ar
  export RANLIB=/tools/bin/$LFS_TGT-ranlib
  export PATH=/tools/bin:/usr/bin:/bin

  ../configure \
    --prefix=/usr \
    --host=$LFS_TGT \
    --build=$(../scripts/config.guess) \
    --enable-kernel=4.19 \
    --with-headers=$LFS/usr/include \
    --disable-nscd \
    libc_cv_slibdir=/usr/lib

  make
  make DESTDIR=$LFS install

  sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd

  cd ../..
  rm -rf glibc-*/
  echo "✅ glibc installed into \$LFS/usr (per LFS)."
}

sync_glibc_headers() {
  echo "🗂  Syncing glibc headers ..."
  if [[ ! -e $LFS/usr/include/stdio.h ]]; then
    mkdir -pv $LFS/usr/include
    cp -R $LFS/tools/include/*  $LFS/usr/include/
  fi
  echo "✅  glibc headers copied to \$LFS/usr/include"
}

adjust_toolchain() {
  echo "🔧 Adjusting temporary toolchain (§5.10) ..."

  # start files
  mkdir -pv "$LFS/usr/lib"
  for f in crt1.o crti.o crtn.o; do
    [ -e "$LFS/usr/lib/$f" ] || ln -sv "/tools/lib/$f" "$LFS/usr/lib/$f"
  done

  # dynamic linker (x86_64)
  if [ "$(uname -m)" = x86_64 ]; then
    mkdir -pv "$LFS/lib64"
    ln -sfv /tools/lib/ld-linux-x86-64.so.2 "$LFS/lib64/ld-linux-x86-64.so.2"
    [ -e "$LFS/usr/lib/ld-linux-x86-64.so.2" ] || ln -sv /tools/lib/ld-linux-x86-64.so.2 "$LFS/usr/lib/ld-linux-x86-64.so.2"
  fi

  # libc symlinks (for link)
  [ -e "$LFS/usr/lib/libc.so" ]          || ln -sv /tools/lib/libc.so "$LFS/usr/lib/libc.so"
  [ -e "$LFS/usr/lib/libc_nonshared.a" ] || ln -sv /tools/lib/libc_nonshared.a "$LFS/usr/lib/libc_nonshared.a"
}

build_coreutils_pass1() {
  echo "🔧  coreutils-8.32 (pass 1)…"
  rm -rf coreutils-8.32
  tar -xf coreutils-8.32.tar.xz
  cd coreutils-8.32

  #──── configure ────────────────────────────────────────────
  export FORCE_UNSAFE_CONFIGURE=1
  export PATH=/tools/bin:/usr/bin:/bin

  CC=/tools/bin/${LFS_TGT}-gcc \
  CFLAGS="-DMB_LEN_MAX=16" \
  ./configure --prefix=/tools --host=$LFS_TGT \
              --build=$(./build-aux/config.guess) \
              --enable-install-program=hostname \
              --enable-no-install-program=kill,uptime \
              --disable-nls

  #──── build ────────────────────────────────────────────────
  make -j"$(nproc)"

  #──── Use host tools for some commands ───────────────────
  for f in rm mv ln basename install dircolors; do
    mkdir -p src
    if [ -f src/$f ]; then
        cp -f /bin/$(basename $f) src/$f
    fi
  done

  #──── install with path which use host tools ───────────────
  PATH=/usr/bin:/bin make install

  cd ..
  rm -rf coreutils-8.32
  echo "✅  coreutils-8.32 (pass 1) done."
}

_patch_termcap() {
  local file=lib/termcap/tparam.c

  grep -q '<unistd.h>' "$file" && return
  echo "🩹  Patching $file (add <unistd.h>)"

  if grep -nq '<stdlib.h>' "$file"; then
    sed -i '0,/<stdlib.h>/a #include <unistd.h>' "$file"
  else
    sed -i '1a #include <unistd.h>' "$file"
  fi
}

build_bash_pass1() {
  export PATH=/tools/bin:/usr/bin:/bin
  hash -r
  echo "🔧  Bash-5.2 (pass 1)…"
  rm -rf bash-*/
  tar -xf bash-5.2*.tar.*z
  cd bash-5.2*/

  _patch_termcap

  # ---- configure ----
  chmod -R a+rwx support
  ./configure  --prefix=/tools \
               --build=$(./support/config.guess) \
               --host=$LFS_TGT \
               --without-bash-malloc \
               --without-installed-readline \
               --without-curses \
               --disable-nls

  make -j"$(nproc)"
  make install
  ln -sv bash /tools/bin/sh

  cd ..
  rm -rf bash-5.2*/
  echo "✅  Bash-5.2 (pass 1) done."
}

build_make_pass1() {
  echo "🔧  make (pass 1)…"
  rm -rf make-*/
  tar -xf make-*.tar.*z
  cd make-*/

  export PATH=/tools/bin:/usr/bin:/bin
  hash -r
  export CONFIG_SHELL=/bin/bash
  ./configure --prefix=/tools --without-guile --host=$LFS_TGT

  make -j$(nproc) > make.log 2>&1 || {
    echo "❌ make failed. Dumping last 50 lines of make.log:"
    tail -n 50 make.log
    exit 1
  }
  make install

  cd ..
  rm -rf make-*/
  echo "✅  make (pass 1) done."
}


build_binutils_pass1
build_gcc_pass1
build_linux_headers
check_linux_headers
build_glibc
# sync_glibc_headers
adjust_toolchain
build_bash_pass1
build_coreutils_pass1
build_make_pass1
