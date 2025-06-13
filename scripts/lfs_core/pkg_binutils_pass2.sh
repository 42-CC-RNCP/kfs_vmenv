#!/bin/bash
set -e

echo "🔧 [LFS] Building binutils (pass 2)..."

cd /sources
tar -xf binutils-*.tar.*z
cd binutils-*/

mkdir -v build
cd build

../configure --prefix=/usr        \
             --build=$(../config.guess) \
             --host=$(uname -m)-lfs-linux-gnu \
             --disable-nls        \
             --enable-shared      \
             --disable-werror     \
             --enable-64-bit-bfd

make -j$(nproc)
make tooldir=/usr install

cd /sources
rm -rf binutils-*/

echo "✅ [LFS] binutils (pass 2) installed."
