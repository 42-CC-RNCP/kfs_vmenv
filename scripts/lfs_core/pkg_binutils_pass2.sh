#!/bin/bash
set -e

export PATH=/tools/bin:/bin:/usr/bin
hash -r

echo "🔧 [LFS] Building binutils (pass 2)..."

export LFS_TGT=$(uname -m)-lfs-linux-gnu
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/tools/bin

cd /sources
rm -rf binutils-*/
tar -xf binutils-*.tar.*z
cd binutils-*/

mkdir -v build
cd build

../configure --prefix=/usr              \
             --build=$(../config.guess) \
             --host=$LFS_TGT            \
             --disable-nls              \
             --enable-shared            \
             --disable-werror           \
             --enable-64-bit-bfd

make -j$(nproc) > make.log 2>&1 || {
    echo "❌ make failed. Dumping last 50 lines of make.log:"
    tail -n 50 make.log
    exit 1
  }
make tooldir=/usr install

cd /sources
rm -rf binutils-*/

echo "✅ [LFS] binutils (pass 2) installed."
