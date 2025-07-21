#!/bin/bash
# build_pass2.sh  ——  LFS Chapter 8
set -euo pipefail

export PATH=/tools/bin:/bin:/usr/bin:/sbin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
SRC=/sources

_unpack () {
  echo "cd $SRC && rm -rf $1 ${1%%-*}-*/"
  echo "tar -xf $1.tar.*z && cd ${2:-$1}"
  cd "$SRC"
  rm -rf "$1"      "${1%%-*}"-*/
  tar -xf "$1".tar.*z
  cd "${2:-$1}"
}

_clean () { cd "$SRC" && rm -rf "$1" "${1%%-*}"-*/; }

_run_make () { make; make install; }

_header () { printf "\e[34m🔷 %s...\e[0m\n" "$*"; }


### 0  Verify environment ########################################################
_header "Sanity check toolchain (has /tools)"
echo 'int main(){}' > dummy.c
${LFS_TGT}-gcc dummy.c -o dummy
rm dummy dummy.c

### 1  Man-pages ##############################################################
_header "Man-pages"
_unpack man-pages-6.*
make prefix=/usr install
_clean man-pages-6.*

### 2  Iana-etc ###############################################################
_header "Iana-etc"
_unpack iana-etc-*
make
make prefix=/usr install
_clean iana-etc-*

### 3  Glibc ##################################################################
_header "Glibc-2.39"
_unpack glibc-2.39
mkdir build && cd build
../configure --prefix=/usr --disable-werror --enable-kernel=4.19
_run_make
cat >/etc/nsswitch.conf <<EOF
passwd: files
group:  files
shadow: files
hosts:  files dns
networks: files
EOF
_clean glibc-2.39

### 4  Sanity check toolchain (no /tools) ######################################
_header "Sanity check toolchain (no /tools)"
echo 'int main(){}' | gcc -xc -
readelf -l a.out | grep -q '/tools' && { echo '❌ toolchain still ref /tools' ; exit 1; }
rm a.out

### 5  Zlib Bzip2 Xz File Readline M4 Bc ###############################
for PKG in zlib-1.3.1 bzip2-1.0.8 xz-5.6.0 file-5.46 readline-8.2 m4-1.4.19 bc-6.7.7
do
  case $PKG in
    zlib-*)      CONF=./configure\ --prefix=/usr ;;
    bzip2-*)     _header "Bzip2"; _unpack "$PKG"
                 make -f Makefile-libbz2_so
                 make PREFIX=/usr install
                 _clean "$PKG"; continue ;;
    xz-*)        CONF=./configure\ --prefix=/usr ;;
    file-*)      CONF=./configure\ --prefix=/usr ;;
    readline-*)  CONF=./configure\ --prefix=/usr\ --disable-static ;;
    m4-*)        CONF=./configure\ --prefix=/usr ;;
    bc-*)        CONF=./configure\ --prefix=/usr ;;
  esac
  _header "$PKG"
  _unpack "$PKG"
  eval $CONF
  _run_make
  _clean "$PKG"
done

### 6  Binutils-pass2 #########################################################
_header "Binutils-pass2"
_unpack binutils-2.44
mkdir build && cd build
../configure --prefix=/usr --build=$(../config.guess) \
             --host=$LFS_TGT --disable-nls --enable-shared --enable-64-bit-bfd
_run_make
_clean binutils-2.44

### 7  GMP MPFR MPC ###########################################################
for PKG in gmp-6.* mpfr-4.* mpc-1.*
do
  case $PKG in
    gmp-*)  CONF=./configure\ --prefix=/usr\ --enable-cxx\ --disable-static ;;
    mpfr-*) CONF=./configure\ --prefix=/usr\ --disable-static\ --enable-thread-safe ;;
    mpc-*)  CONF=./configure\ --prefix=/usr\ --disable-static ;;
  esac
  _header "$PKG"
  _unpack "$PKG"
  eval $CONF
  _run_make
  _clean "$PKG"
done

### 8  GCC-pass2 ##############################################################
_header "GCC-pass2"
_unpack gcc-14.2.0
mkdir build && cd build
../configure --prefix=/usr --build=$(../config.guess) --host=$LFS_TGT \
             --enable-languages=c,c++ --disable-multilib --disable-bootstrap \
             --with-system-zlib
_run_make
ln -sv gcc /usr/bin/cc
_clean gcc-14.2.0

### 9  Coreutils-pass2 ########################################################
_header "Coreutils-pass2"
_unpack coreutils-9.3
./configure --prefix=/usr --enable-no-install-program=kill,uptime
_run_make
mv -v /usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,echo,ln,mkdir,mknod,mv,pwd,rm,rmdir,stty,true,false,sleep} /bin
_clean coreutils-9.3
hash -r

### 10  Diffutils Gawk Findutils Grep Sed ##################################
for PKG in diffutils-3.* gawk-5.* findutils-4.* grep-3.* sed-4.*
do
  _header "$PKG"
  _unpack "$PKG"
  ./configure --prefix=/usr
  _run_make
  _clean "$PKG"
done

### 11  Flex Bison Gettext ###################################################
_header "Flex"
_unpack flex-2.6.4
HELP2MAN=/usr/bin/true ./configure --prefix=/usr --disable-static
_run_make
ln -sv flex /usr/bin/lex
_clean flex-2.6.4

for PKG in bison-3.* gettext-0.*
do
  _header "$PKG"
  _unpack "$PKG"
  ./configure --prefix=/usr
  _run_make
  _clean "$PKG"
done

##############################################################################
_header "✅ Pass 2 build completed successfully."
