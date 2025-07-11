#!/bin/bash
set -e

echo "🔧 [LFS] Building flex..."

# --- Setup toolchain environment ---
export PATH=/tools/bin:/bin:/usr/bin
export CC=${LFS_TGT}-gcc
export AR=${LFS_TGT}-ar
export RANLIB=${LFS_TGT}-ranlib
export INSTALL=/tools/bin/install
hash -r

# --- Extract & build ---
cd /sources
rm -rf flex-*/
tar -xf flex-*.tar.*z
cd flex-*/

./configure --prefix=/usr \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess) \
            --disable-shared

make -j$(nproc)
make install

ln -sv flex /usr/bin/lex

cd ..
rm -rf flex-*

echo "✅ [LFS] flex installed."
