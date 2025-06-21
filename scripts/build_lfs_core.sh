#!/bin/bash
set -e

export PATH=/tools/bin:$PATH

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
  ../configure --prefix=$LFS/tools \
               --with-sysroot=$LFS \
               --target=$LFS_TGT \
               --disable-nls \
               --disable-werror

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
               --prefix=$LFS/tools \
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

check_linux_headers() {
  header_folder="$MNT_ROOT/usr/include/linux"
  if [[ -d "$header_folder" ]]; then
    echo "✅ Linux headers already installed at $header_folder"
  else
    echo "❌ Linux headers not found at $header_folder"
    echo "Please ensure you have run the init_lfs.sh script first."
    exit 1
  fi
}

build_glibc() {
  echo "🔧 Building glibc..."
  rm -rf glibc-*/

  tar -xf glibc-*.tar.*z
  cd glibc-*/

  mkdir -v build && cd build

  echo "rootsbindir=/tools/bin" > configparms

  echo "🔧 Setting up cross-toolchain environment..."
  export CC=$LFS_TGT-gcc
  export CXX=$LFS_TGT-g++
  export AR=$LFS_TGT-ar
  export RANLIB=$LFS_TGT-ranlib
  export PATH="$LFS/tools/bin:$PATH"

  echo "🧪 Validating header exists..."
  if [[ ! -f $LFS/usr/include/linux/version.h ]]; then
    echo "❌ ERROR: Missing headers at $LFS/usr/include/linux/version.h"
    exit 1
  fi

  ../configure --prefix=/tools \
             --with-sysroot=$LFS \
             --build=$(../scripts/config.guess) \
             --host=$LFS_TGT \
             --enable-kernel=3.2 \
             --with-headers=$LFS/usr/include \
             libc_cv_slibdir=/tools/lib


  make -j$(nproc)
  make install

  cd ../..
  rm -rf glibc-*/
  echo "✅ glibc done."
}

adjust_toolchain() {
  echo "🔧 Adjusting temporary toolchain (§5.10) ..."

  # a. start-files
  echo "🔧 Adjusting start files..."
  mkdir -pv $LFS/usr/lib
  for f in crt1.o crti.o crtn.o ; do
    [ -e $LFS/usr/lib/$f ] || ln -sv $LFS/tools/lib/$f $LFS/usr/lib
  done

  # b. ld-linux
  echo "🔧 Adjusting dynamic linker..."
  case "$(uname -m)" in
    x86_64)
      [ -e $LFS/usr/lib/ld-linux-x86-64.so.2 ] \
        || ln -sv $LFS/tools/lib/ld-linux-x86-64.so.2 $LFS/usr/lib ;;
    i?86)
      [ -e $LFS/usr/lib/ld-linux.so.2 ] \
        || ln -sv $LFS/tools/lib/ld-linux.so.2 $LFS/usr/lib ;;
    aarch64|arm64)
      [ -e $LFS/usr/lib/ld-linux-aarch64.so.1 ] \
        || ln -sv $LFS/tools/lib/ld-linux-aarch64.so.1 $LFS/usr/lib ;;
  esac
  [ -e $LFS/usr/lib/libc.so ]         || ln -sv $LFS/tools/lib/libc.so $LFS/usr/lib
  [ -e $LFS/usr/lib/libc_nonshared.a ]|| ln -sv $LFS/tools/lib/libc_nonshared.a $LFS/usr/lib


  # c. rewrite GCC specs
  echo "🔧 Rewriting GCC specs..."
  GCC_BIN=$LFS/tools/bin/${LFS_TGT}-gcc
  SPECS_DIR=$(dirname $("${GCC_BIN}" -print-libgcc-file-name))
  "${GCC_BIN}" -dumpspecs | sed 's@/tools@@g' > "${SPECS_DIR}/specs"

  # d. sanity test
  echo "🔧 Performing sanity test..."
  echo 'int main(){}' > dummy.c
  "${GCC_BIN}" dummy.c -o dummy
  if readelf -l dummy | grep -q '/tools'; then
      echo "❌  Toolchain still refers to /tools – aborting."
      rm -f dummy.c dummy
      exit 1
  fi
  rm -f dummy.c dummy
  echo "✅ Toolchain adjusted – no /tools reference remains."
}

build_coreutils_pass1() {
  echo "🔧 Building coreutils (pass 1)..."
  rm -rf coreutils-*/

  tar -xf coreutils-*.tar.*z
  cd coreutils-*/

  ./configure --prefix=/tools \
              --host=$LFS_TGT \
              --build=$(./build-aux/config.guess) \
              --enable-install-program=hostname \
              --enable-no-install-program=kill,uptime

  make -j$(nproc)
  make install

  cd ..
  rm -rf coreutils-*/
  echo "✅ coreutils (pass 1) done."
}

# 5. Compiling a Cross-Toolchain
#   - Binutils-2.44 - Pass 1
#   - GCC-14.2.0 - Pass 1
#   - Linux-6.13.4 API Headers
#   - Glibc-2.41
#   - Libstdc++ from GCC-14.2.0
# build_binutils_pass1
# build_gcc_pass1
# check_linux_headers
# build_glibc
adjust_toolchain
build_coreutils_pass1
