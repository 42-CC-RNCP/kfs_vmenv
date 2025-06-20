#!/bin/bash
set -e


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

# 6. Building coreutils (pass 1)
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
build_binutils_pass1
build_gcc_pass1
check_linux_headers
build_glibc
build_coreutils_pass1
