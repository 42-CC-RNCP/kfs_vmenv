#!/bin/bash
set -e

export LFS=${LFS:-/mnt/lfs}
export LFS_TGT=${LFS_TGT:-$(uname -m)-lfs-linux-gnu}
export PATH=$LFS/tools/bin:/usr/bin:/bin
cd $LFS/sources

build_gawk() {
  echo "🔧 Building gawk (pass 1)..."
  rm -rf gawk-*/
  tar -xf gawk-*.tar.*z
  cd gawk-*/
  ./configure --prefix=$LFS/tools --host=$LFS_TGT
  make -j$(nproc)
  make install
  cd ..
  rm -rf gawk-*/
  echo "✅ gawk done."
}

build_bison() {
  echo "🔧 Building bison (pass 1)..."
  rm -rf bison-*/
  tar -xf bison-*.tar.*z
  cd bison-*/
  ./configure --prefix=$LFS/tools --host=$LFS_TGT
  make -j$(nproc)
  make install
  cd ..
  rm -rf bison-*/
  echo "✅ bison done."
}

build_m4() {
  echo "🔧 Building m4 (pass 1)..."
  rm -rf m4-*/
  tar -xf m4-*.tar.*z
  cd m4-*/
  ./configure --prefix=$LFS/tools --host=$LFS_TGT
  make -j$(nproc)
  make install
  cd ..
  rm -rf m4-*/
  echo "✅ m4 done."
}

build_perl() {
  echo "🔧 Building perl (pass 1)..."
  rm -rf perl-*/
  tar -xf perl-*.tar.*z
  cd perl-*/
  sh Configure -des -Dprefix=$LFS/tools -Dman1dir=$LFS/tools/share/man/man1 -Dman3dir=$LFS/tools/share/man/man3 -Dtarget=$LFS_TGT
  make -j$(nproc)
  make install
  cd ..
  rm -rf perl-*/
  echo "✅ perl done."
}

build_python() {
  echo "🔧 Building python (pass 1)..."
  rm -rf Python-*/
  tar -xf Python-*.tar.*z
  cd Python-*/
  ./configure --prefix=$LFS/tools --host=$LFS_TGT --build=$(./config.guess) --without-ensurepip
  make -j$(nproc)
  make install
  cd ..
  rm -rf Python-*/
  echo "✅ python done."
}

build_gawk
build_bison
build_m4
build_perl
build_python
