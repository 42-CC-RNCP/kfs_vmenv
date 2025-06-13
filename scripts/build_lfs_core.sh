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
  tar -xf binutils-*.tar.*z
  cd binutils-*/

  mkdir -v build && cd build
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
  tar -xf gcc-*.tar.*z
  cd gcc-*/

  for dep in mpfr gmp mpc; do
    tar -xf ../$dep-*.tar.*z
    mv -v $dep-* $dep
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

build_linux_headers() {
  echo "🔧 Building Linux kernel API headers..."
  cd $LFS/sources
  tar -xf linux-*.tar.*z
  cd linux-*/

  make mrproper

  make headers
  find usr/include -type f ! -name '*.h' -delete
  cp -rv usr/include $LFS/usr

  cd ..
  rm -rf linux-*/
  echo "✅ Linux API headers installed to $LFS/usr/include"
}

build_glibc() {
  echo "🔧 Building glibc..."
  tar -xf glibc-*.tar.*z
  cd glibc-*/

  mkdir -v build && cd build

  echo "rootsbindir=/tools/bin" > configparms

  ../configure --prefix=/tools \
               --host=$LFS_TGT \
               --build=$(../scripts/config.guess) \
               --enable-kernel=3.2 \
               --with-headers=$LFS/usr/include \
               libc_cv_slibdir=/tools/lib

  make -j$(nproc)
  make install

  cd ../..
  rm -rf glibc-*/
  echo "✅ glibc done."
}

# 5. Compiling a Cross-Toolchain
#   - Binutils-2.44 - Pass 1
#   - GCC-14.2.0 - Pass 1
#   - Linux-6.13.4 API Headers
#   - Glibc-2.41
#   - Libstdc++ from GCC-14.2.0
build_binutils_pass1
build_gcc_pass1
# build_linux_headers
build_glibc
