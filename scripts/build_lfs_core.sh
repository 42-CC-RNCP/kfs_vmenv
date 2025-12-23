#!/bin/bash
set -e

export PATH=/tools/bin:/usr/bin:/bin
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
  ../configure --prefix=/tools            \
               --with-sysroot=$LFS        \
               --with-lib-path=/tools/lib \
               --target=$LFS_TGT          \
               --disable-nls              \
               --disable-werror

  make -j$(nproc)
  case $(uname -m) in
    x86_64) mkdir -v /tools/lib && ln -sv lib /tools/lib64 ;;
  esac
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
  
  for file in gcc/config/{linux,i386/linux{,64}}.h
  do
    cp -uv $file{,.orig}
    sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
        -e 's@/usr@/tools@g' $file.orig > $file
    echo '
  #undef STANDARD_STARTFILE_PREFIX_1
  #undef STANDARD_STARTFILE_PREFIX_2
  #define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
  #define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
    touch $file.orig
  done

  case $(uname -m) in
    x86_64)
      sed -e '/m64=/s/lib64/lib/' \
          -i.orig gcc/config/i386/t-linux64
  ;;
  esac

  mkdir -v build && cd build
  ../configure                                       \
                --target=$LFS_TGT                              \
                --prefix=/tools                                \
                --with-glibc-version=2.11                      \
                --with-sysroot=$LFS                            \
                --with-newlib                                  \
                --without-headers                              \
                --with-local-prefix=/tools                     \
                --with-native-system-header-dir=/tools/include \
                --disable-nls                                  \
                --disable-shared                               \
                --disable-multilib                             \
                --disable-decimal-float                        \
                --disable-threads                              \
                --disable-libatomic                            \
                --disable-libgomp                              \
                --disable-libmpx                               \
                --disable-libquadmath                          \
                --disable-libssp                               \
                --disable-libvtv                               \
                --disable-libstdcxx                            \
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
  cp -rv dest/include/* /tools/include

  cd ..
  rm -rf linux-*/
  echo "✅ Linux headers installed to /tools/include"
}

build_glibc() {
  echo "🔧 Building glibc (LFS ch5)..."
  rm -rf glibc-*/
  tar -xf glibc-*.tar.*z
  cd glibc-*/

  mkdir -v build && cd build

  ../configure                             \
      --prefix=/tools                    \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --enable-kernel=3.2                \
      --with-headers=/tools/include

  make -j$(nproc)
  make install

  #──── Verify glibc installation ───────────────────────────
  echo 'int main(){}' > dummy.c
  $LFS_TGT-gcc dummy.c
  readelf -l a.out | grep ': /tools'
  rm -v dummy.c a.out

  cd ../..
  rm -rf glibc-*/
  echo "✅ glibc installed into /tools"
}

build_libstdc() {
  echo "🔧  Building libstdc++ (pass 1)…"
  rm -rf gcc-*/
  tar -xf gcc-*.tar.*z
  cd gcc-*/

  mkdir -v build && cd build
  ../libstdc++-v3/configure           \
                            --host=$LFS_TGT                 \
                            --prefix=/tools                 \
                            --disable-multilib              \
                            --disable-nls                   \
                            --disable-libstdcxx-threads     \
                            --disable-libstdcxx-pch         \
                            --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/8.2.0

  make -j$(nproc)
  make install

  cd ../..
  rm -rf gcc-*/
  echo "✅  libstdc++ (pass 1) done."
}

build_binutils_pass2() {
  echo "🔧 Building binutils (pass 2)..."
  echo "📦 Cleaning previous binutils directory if it exists..."
  rm -rf binutils-*/

  tar -xf binutils-*.tar.*z
  cd binutils-*/

  (mkdir -v build ) && cd build
  CC=$LFS_TGT-gcc                \
  AR=$LFS_TGT-ar                 \
  RANLIB=$LFS_TGT-ranlib         \
  ../configure                   \
      --prefix=/tools            \
      --disable-nls              \
      --disable-werror           \
      --with-lib-path=/tools/lib \
      --with-sysroot=$LFS        \
      --target=$LFS_TGT

  make -j$(nproc)
  make install

  make -C ld clean
  make -C ld LIB_PATH=/usr/lib:/lib
  cp -v ld/ld-new /tools/bin

  cd ../..
  rm -rf binutils-*/
  echo "✅ binutils (pass 2) done."
}

build_gcc_pass2() {
  echo "🔧 Building gcc (pass 2)..."
  echo "📦 Cleaning previous gcc directory if it exists..."
  rm -rf gcc-*/ > /dev/null
  rm -rf mpfr-*/ gmp-*/ mpc-*/ > /dev/null

  tar -xf gcc-*.tar.*z
  cd gcc-*/
  cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
    `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h

  for file in gcc/config/{linux,i386/linux{,64}}.h
  do
    cp -uv $file{,.orig}
    sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
        -e 's@/usr@/tools@g' $file.orig > $file
    echo '
  #undef STANDARD_STARTFILE_PREFIX_1
  #undef STANDARD_STARTFILE_PREFIX_2
  #define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
  #define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
    touch $file.orig
  done

  case $(uname -m) in
    x86_64)
      sed -e '/m64=/s/lib64/lib/' \
          -i.orig gcc/config/i386/t-linux64
    ;;
  esac

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
  CC=$LFS_TGT-gcc                                    \
  CXX=$LFS_TGT-g++                                   \
  AR=$LFS_TGT-ar                                     \
  RANLIB=$LFS_TGT-ranlib                             \
  ../configure                                       \
      --prefix=/tools                                \
      --with-local-prefix=/tools                     \
      --with-native-system-header-dir=/tools/include \
      --enable-languages=c,c++                       \
      --disable-libstdcxx-pch                        \
      --disable-multilib                             \
      --disable-bootstrap                            \
      --disable-libgomp

  make -j$(nproc)
  make install

  ln -sv gcc /tools/bin/cc

  #──── Verify gcc installation ───────────────────────────
  echo 'int main(){}' > dummy.c
  cc dummy.c
  readelf -l a.out | grep ': /tools'
  rm -v dummy.c a.out

  cd ../..
  rm -rf gcc-*/
  echo "✅ gcc (pass 2) done."
}

build_tcl() {
  echo "🔧 Building tcl..."
  rm -rf tcl*/
  tar -xf tcl*.tar.*z
  cd tcl*/

  cd unix
  ./configure --prefix=/tools

  make -j$(nproc)
  make install

  chmod -v u+w /tools/lib/libtcl8.6.so
  make install-private-headers
  ln -sv tclsh8.6 /tools/bin/tclsh

  cd ../..
  rm -rf tcl*/
  echo "✅ tcl installed into /tools"
}

build_expect() {
  echo "🔧 Building expect..."
  rm -rf expect*/
  tar -xf expect*.tar.*z
  cd expect*/

  cp -v configure{,.orig}
  sed 's:/usr/local/bin:/bin:' configure.orig > configure

  ./configure --prefix=/tools       \
              --with-tcl=/tools/lib \
              --with-tclinclude=/tools/include

  make -j$(nproc)
  make test
  make SCRIPTS="" install

  cd ..
  rm -rf expect*/
  echo "✅ expect installed into /tools"
}

build_dejagnu() {
  echo "🔧 Building DejaGNU..."
  rm -rf dejagnu-*/
  tar -xf dejagnu-*.tar.*z
  cd dejagnu-*/

  ./configure --prefix=/tools

  make -j$(nproc)
  make install

  cd ..
  rm -rf dejagnu-*/
  echo "✅ DejaGNU installed into /tools"
}

build_m4() {
  echo "🔧 Building m4..."
  rm -rf m4-*/
  tar -xf m4-*.tar.*z
  cd m4-*/

  sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
  echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h

  ./configure --prefix=/tools

  make -j$(nproc)
  make check
  make install

  cd ..
  rm -rf m4-*/
  echo "✅ m4 installed into /tools"
}

build_ncurses() {
  echo "🔧 Building ncurses..."
  rm -rf ncurses-*/
  tar -xf ncurses-*.tar.*z
  cd ncurses-*/

  sed -i s/mawk// configure

  ./configure --prefix=/tools \
              --with-shared   \
              --without-debug \
              --without-ada   \
              --enable-widec  \
              --enable-overwrite

  make -j$(nproc)
  make install

  ln -s libncursesw.so /tools/lib/libncurses.so

  cd ..
  rm -rf ncurses-*/
  echo "✅ ncurses installed into /tools"
}

build_bash() {
  echo "🔧 Building bash..."
  rm -rf bash-*/
  tar -xf bash-*.tar.*z
  cd bash-*/

  ./configure --prefix=/tools --without-bash-malloc

  make -j$(nproc)
  make install

  ln -sv bash /tools/bin/sh

  cd ..
  rm -rf bash-*/
  echo "✅ bash installed into /tools"
}

build_bison() {
  echo "🔧 Building bison..."
  rm -rf bison-*/
  tar -xf bison-*.tar.*z
  cd bison-*/

  ./configure --prefix=/tools

  make -j$(nproc)
  make install

  cd ..
  rm -rf bison-*/
  echo "✅ bison installed into /tools"
}

build_bzip2() {
  echo "🔧 Building bzip2..."
  rm -rf bzip2-*/
  tar -xf bzip2-*.tar.*z
  cd bzip2-*/

  make
  make PREFIX=/tools install

  cd ..
  rm -rf bzip2-*/
  echo "✅ bzip2 installed into /tools"
}

build_coreutils() {
  echo "🔧 Building coreutils..."
  rm -rf coreutils-*/
  tar -xf coreutils-*.tar.*z
  cd coreutils-*/

  ./configure --prefix=/tools --enable-install-program=hostname

  make -j$(nproc)
  make install

  cd ..
  rm -rf coreutils-*/
  echo "✅ coreutils installed into /tools"
}

build_diffutils() {
  echo "🔧 Building diffutils..."
  rm -rf diffutils-*/
  tar -xf diffutils-*.tar.*z
  cd diffutils-*/

  ./configure --prefix=/tools

  make -j$(nproc)
  make install

  cd ..
  rm -rf diffutils-*/
  echo "✅ diffutils installed into /tools"
}

build_file() {
  echo "🔧 Building file..."
  rm -rf file-*/
  tar -xf file-*.tar.*z
  cd file-*/

  ./configure --prefix=/tools

  make -j$(nproc)
  make install

  cd ..
  rm -rf file-*/
  echo "✅ file installed into /tools"
}

build_findutils() {
  echo "🔧 Building findutils..."
  rm -rf findutils-*/
  tar -xf findutils-*.tar.*z
  cd findutils-*/

  sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' gl/lib/*.c
  sed -i '/unistd/a #include <sys/sysmacros.h>' gl/lib/mountlist.c
  echo "#define _IO_IN_BACKUP 0x100" >> gl/lib/stdio-impl.h

  ./configure --prefix=/tools

  make -j$(nproc)
  make install

  cd ..
  rm -rf findutils-*/
  echo "✅ findutils installed into /tools"
}

build_gawk() {
  echo "🔧 Building gawk..."
  rm -rf gawk-*/
  tar -xf gawk-*.tar.*z
  cd gawk-*/

  ./configure --prefix=/tools

  make -j$(nproc)
  make install

  cd ..
  rm -rf gawk-*/
  echo "✅ gawk installed into /tools"
}

build_gettext() {
  echo "🔧 Building gettext..."
  rm -rf gettext-*/
  tar -xf gettext-*.tar.*z
  cd gettext-*/

  EMACS="no" ./configure --prefix=/tools --disable-shared

  make -C gnulib-lib
  make -C intl pluralx.c
  make -C src msgfmt
  make -C src msgmerge
  make -C src xgettext

  cp -v src/{msgfmt,msgmerge,xgettext} /tools/bin

  cd ..
  rm -rf gettext-*/
  echo "✅ gettext installed into /tools"
}

build_grep() {
  echo "🔧 Building grep..."
  rm -rf grep-*/
  tar -xf grep-*.tar.*z
  cd grep-*/

  ./configure --prefix=/tools

  make -j$(nproc)
  make install

  cd ..
  rm -rf grep-*/
  echo "✅ grep installed into /tools"
}

build_gzip() {
  echo "🔧 Building gzip..."
  rm -rf gzip-*/
  tar -xf gzip-*.tar.*z
  cd gzip-*/

  ./configure --prefix=/tools

  make -j$(nproc)
  make install

  cd ..
  rm -rf gzip-*/
  echo "✅ gzip installed into /tools"
}

build_make() {
  echo "🔧 Building make..."
  rm -rf make-*/
  tar -xf make-*.tar.*z
  cd make-*/

  sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c
  ./configure --prefix=/tools

  make -j$(nproc)
  make install

  cd ..
  rm -rf make-*/
  echo "✅ make installed into /tools"
}

build_patch() {
  echo "🔧 Building patch..."
  rm -rf patch-*/
  tar -xf patch-*.tar.*z
  cd patch-*/

  ./configure --prefix=/tools

  make -j$(nproc)
  make install

  cd ..
  rm -rf patch-*/
  echo "✅ patch installed into /tools"
}

build_perl() {
  echo "🔧 Building Perl..."
  rm -rf perl-*/
  tar -xf perl-*.tar.*z
  cd perl-*/

  sh Configure -des -Dprefix=/tools -Dlibs=-lm -Uloclibpth -Ulocincpth

  make

  cp -v perl cpan/podlators/scripts/pod2man /tools/bin
  mkdir -pv /tools/lib/perl5/5.28.1
  cp -Rv lib/* /tools/lib/perl5/5.28.1

  cd ..
  rm -rf perl-*/
  echo "✅ perl installed into /tools"
}

build_python() {
  echo "🔧 Building Python..."
  rm -rf Python-*/
  tar -xf Python-*.tar.*z
  cd Python-*/

  sed -i '/def add_multiarch_paths/a \        return' setup.py

  ./configure --prefix=/tools --enable-shared --without-ensurepip

  make -j$(nproc)
  make install

  cd ..
  rm -rf Python-*/
  echo "✅ Python installed into /tools"
}

# build_binutils_pass1
# build_gcc_pass1
# build_linux_headers
# build_glibc
# build_libstdc
# build_binutils_pass2
# build_gcc_pass2

build_tcl
build_expect
build_dejagnu
build_m4
build_ncurses
build_bash
build_bison
build_bzip2
build_coreutils
build_diffutils
build_file
build_findutils
build_gawk
build_gettext
build_grep
build_make
build_patch
build_perl
build_python

echo "🎉 All LFS core toolchain components built and installed into /tools successfully!"