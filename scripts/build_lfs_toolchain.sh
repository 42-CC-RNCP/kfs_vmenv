#!/bin/bash
set -eEuo pipefail

echo "🔧 ch6.5 + ch6.6 + ch6.7 (rerunnable)"

STAMP_DIR="/.kfs/stamps/ch6"
mkdir -p "$STAMP_DIR"

run_step() {
  local name="$1"; shift
  local stamp="$STAMP_DIR/$name.done"
  if [[ -f "$stamp" ]]; then
    echo "✅ (skip) $name"
    return 0
  fi
  echo "🔷 RUN $name"
  "$@"
  touch "$stamp"
  echo "✅ DONE $name"
}

debug_toolchain_snapshot() {
  echo "=== SNAPSHOT ==="
  echo "PATH=$PATH"
  echo "MAKEFLAGS=${MAKEFLAGS:-}"
  type -a gcc ld as ar ranlib make || true
  ls -1 /tools/bin/*-ar 2>/dev/null | head -n 5 || true
  ls -1 /tools/bin/*-as 2>/dev/null | head -n 5 || true
  ls -1 /tools/bin/*-ld 2>/dev/null | head -n 5 || true
  echo "==============="
}

ensure_binutils_symlinks() {
  local tgt="${LFS_TGT:-}"

  # infer prefix if LFS_TGT not provided
  if [ -z "$tgt" ]; then
    local as_path
    as_path="$(ls -1 /tools/bin/*-as 2>/dev/null | head -n1 || true)"
    if [ -n "$as_path" ]; then
      tgt="$(basename "$as_path")"
      tgt="${tgt%-as}"
    fi
  fi

  if [ -z "$tgt" ]; then
    echo "❌ ERROR: cannot infer binutils prefix in /tools/bin (no *-as found)" >&2
    exit 1
  fi

  # link common binutils names if missing
  for tool in as ld ar ranlib nm strip objcopy objdump readelf; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      if [ -x "/tools/bin/${tgt}-${tool}" ]; then
        ln -sfv "/tools/bin/${tgt}-${tool}" "/tools/bin/${tool}"
      fi
    fi
  done

  # hard fail if assembler still missing
  command -v as >/dev/null 2>&1 || { echo "❌ ERROR: 'as' still missing" >&2; exit 1; }
}

create_dirs() {
  mkdir -pv /{bin,boot,etc/{opt,sysconfig},home,lib/firmware,mnt,opt}
  mkdir -pv /{media/{floppy,cdrom},sbin,srv,var}
  install -dv -m 0750 /root
  install -dv -m 1777 /tmp /var/tmp
  mkdir -pv /usr/{,local/}{bin,include,lib,sbin,src}
  mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
  mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
  mkdir -pv /usr/libexec
  mkdir -pv /usr/{,local/}share/man/man{1..8}
  case "$(uname -m)" in x86_64) mkdir -pv /lib64 ;; esac
  mkdir -pv /var/{log,mail,spool}
  mkdir -pv /var/{opt,cache,lib/{color,misc,locate},local}

  # rerun safe
  [[ -L /var/run  || ! -e /var/run  ]] || rm -rf /var/run
  [[ -L /var/lock || ! -e /var/lock ]] || rm -rf /var/lock
  ln -svf /run      /var/run
  ln -svf /run/lock /var/lock
}

create_symlinks() {
  # rerun safe
  ln -svf /tools/bin/{bash,cat,chmod,dd,echo,ln,mkdir,pwd,rm,stty,touch} /bin
  ln -svf /tools/bin/{env,install,perl,printf} /usr/bin

  mkdir -pv /usr/lib
  ln -svf /tools/lib/libgcc_s.so{,.1} /usr/lib || true
  ln -svf /tools/lib/libstdc++.{a,so{,.6}} /usr/lib || true

  install -vdm755 /usr/lib/pkgconfig

  # /bin/sh rerun safe
  [[ -L /bin/sh || ! -e /bin/sh ]] || rm -f /bin/sh
  ln -svf bash /bin/sh

  [[ -L /etc/mtab || ! -e /etc/mtab ]] || rm -f /etc/mtab
  ln -svf /proc/self/mounts /etc/mtab
}

create_passwd_group() {
  cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/var/run/dbus:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF

  cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:61:
wheel:x:97:
nogroup:x:99:
users:x:999:
EOF
}

init_var_log_files() {
  mkdir -pv /var/log
  touch /var/log/{btmp,lastlog,faillog,wtmp}
  chgrp -v utmp /var/log/lastlog
  chmod -v 664  /var/log/lastlog
  chmod -v 600  /var/log/btmp
}

build_linux_headers() {
  echo "🔧 Building Linux kernel headers ch6.7"
  rm -rf linux-*/ || true
  tar -xf linux-*.tar.*
  cd linux-*/

  make mrproper
  make INSTALL_HDR_PATH=dest headers_install
  find dest/include \( -name .install -o -name ..install.cmd \) -delete
  cp -rv dest/include/* /usr/include

  cd /sources
  rm -rf linux-*/ || true
}

build_manpages() {
  echo "🔧 Building man-pages ch6.8"
  rm -rf man-pages-*/ || true
  tar -xf man-pages-*.tar.*
  cd man-pages-*/

  make install
  cd /sources
  rm -rf man-pages-*/
}

build_glibc() {
  echo "🔧 Building glibc ch6.9"
  rm -rf glibc-*/ || true
  tar -xf glibc-*.tar.*
  cd glibc-*/

  patch -Np1 -i /sources/glibc-2.29-fhs-1.patch
  ln -sfv /tools/lib/gcc /usr/lib

  case $(uname -m) in
      i?86)    GCC_INCDIR=/usr/lib/gcc/$(uname -m)-pc-linux-gnu/8.2.0/include
              ln -sfv ld-linux.so.2 /lib/ld-lsb.so.3
      ;;
      x86_64) GCC_INCDIR=/usr/lib/gcc/x86_64-pc-linux-gnu/8.2.0/include
              ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64
              ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3
      ;;
  esac

  rm -f /usr/include/limits.h

  mkdir -v build
  cd       build

  CC="gcc -isystem $GCC_INCDIR -isystem /usr/include" \
  ../configure --prefix=/usr                          \
              --disable-werror                       \
              --enable-kernel=3.2                    \
              --enable-stack-protector=strong        \
              libc_cv_slibdir=/lib
  unset GCC_INCDIR

  make

  case $(uname -m) in
    i?86)   ln -sfnv $PWD/elf/ld-linux.so.2        /lib ;;
    x86_64) ln -sfnv $PWD/elf/ld-linux-x86-64.so.2 /lib ;;
  esac

  set +e
  make -k check 2>&1
  set -e

  echo "🔧 Installing glibc..."
  touch /etc/ld.so.conf
  sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
  make install

  cp -v ../nscd/nscd.conf /etc/nscd.conf
  mkdir -pv /var/cache/nscd

  mkdir -pv /usr/lib/locale
  localedef -i POSIX -f UTF-8 C.UTF-8 2> /dev/null || true
  localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
  localedef -i de_DE -f ISO-8859-1 de_DE
  localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
  localedef -i de_DE -f UTF-8 de_DE.UTF-8
  localedef -i el_GR -f ISO-8859-7 el_GR
  localedef -i en_GB -f UTF-8 en_GB.UTF-8
  localedef -i en_HK -f ISO-8859-1 en_HK
  localedef -i en_PH -f ISO-8859-1 en_PH
  localedef -i en_US -f ISO-8859-1 en_US
  localedef -i en_US -f UTF-8 en_US.UTF-8
  localedef -i es_MX -f ISO-8859-1 es_MX
  localedef -i fa_IR -f UTF-8 fa_IR
  localedef -i fr_FR -f ISO-8859-1 fr_FR
  localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
  localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
  localedef -i it_IT -f ISO-8859-1 it_IT
  localedef -i it_IT -f UTF-8 it_IT.UTF-8
  localedef -i ja_JP -f EUC-JP ja_JP
  localedef -i ja_JP -f SHIFT_JIS ja_JP.SIJS 2> /dev/null || true
  localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
  localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
  localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
  localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
  localedef -i zh_CN -f GB18030 zh_CN.GB18030
  localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS

  cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF

  tar -xf /sources/tzdata2018i.tar.gz
  ZONEINFO=/usr/share/zoneinfo
  mkdir -pv $ZONEINFO/{posix,right}

  for tz in etcetera southamerica northamerica europe africa antarctica  \
            asia australasia backward pacificnew systemv; do
      zic -L /dev/null   -d $ZONEINFO       ${tz}
      zic -L /dev/null   -d $ZONEINFO/posix ${tz}
      zic -L leapseconds -d $ZONEINFO/right ${tz}
  done

  cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
  zic -d $ZONEINFO -p America/New_York
  unset ZONEINFO

  cp -v /usr/share/zoneinfo/Europe/Vienna /etc/localtime

  cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF

  cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
  mkdir -pv /etc/ld.so.conf.d

  cd /sources
  rm -rf glibc-*/
}

adjust_toolchain() {
  echo "🔧 Adjusting toolchain ch6.10"
  mv -v /tools/bin/{ld,ld-old}
  mv -v /tools/$(uname -m)-pc-linux-gnu/bin/{ld,ld-old}
  mv -v /tools/bin/{ld-new,ld}
  ln -sv /tools/bin/ld /tools/$(uname -m)-pc-linux-gnu/bin/ld

  gcc -dumpspecs | sed -e 's@/tools@@g'                   \
    -e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
    -e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' >      \
    `dirname $(gcc --print-libgcc-file-name)`/specs

  # test the adjusted toolchain
  echo "🔧 Testing the adjusted toolchain..."
  echo 'int main(){}' > dummy.c
  cc dummy.c -v -Wl,--verbose &> dummy.log
  readelf -l a.out | grep ': /lib'

  grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
  grep -B1 '^ /usr/include' dummy.log
  grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
  grep "/lib.*/libc.so.6 " dummy.log
  grep found dummy.log
  rm -v dummy.c a.out dummy.log
}

build_zlib() {
  echo "🔧 Building zlib ch6.11"
  rm -rf zlib-*/ || true
  tar -xf zlib-*.tar.*
  cd zlib-*/

  ./configure --prefix=/usr
  make
  make check
  make install

  mv -v /usr/lib/libz.so.* /lib
  ln -sfv ../../lib/$(readlink /usr/lib/libz.so) /usr/lib/libz.so

  cd /sources
  rm -rf zlib-*/
}

build_file() {
  echo "🔧 Building file ch6.12"
  rm -rf file-*/ || true
  tar -xf file-*.tar.*
  cd file-*/

  ./configure --prefix=/usr
  make
  make check
  make install

  cd /sources
  rm -rf file-*/
}

build_readline() {
  echo "🔧 Building readline ch6.13"
  rm -rf readline-*/ || true
  tar -xf readline-*.tar.*
  cd readline-*/

  sed -i '/MV.*old/d' Makefile.in
  sed -i '/{OLDSUFF}/c:' support/shlib-install

  ./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/readline-8.0
  make SHLIB_LIBS="-L/tools/lib -lncursesw"
  make SHLIB_LIBS="-L/tools/lib -lncursesw" install

  mv -v /usr/lib/lib{readline,history}.so.* /lib
  chmod -v u+w /lib/lib{readline,history}.so.*
  ln -sfv ../../lib/$(readlink /usr/lib/libreadline.so) /usr/lib/libreadline.so
  ln -sfv ../../lib/$(readlink /usr/lib/libhistory.so ) /usr/lib/libhistory.so

  cd /sources
  rm -rf readline-*/
}

build_m4() {
  echo "🔧 Building m4 ch6.14"
  rm -rf m4-*/ || true
  tar -xf m4-*.tar.*
  cd m4-*/

  sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
  echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h
  ./configure --prefix=/usr
  make
  make check
  make install

  cd /sources
  rm -rf m4-*/
}

build_bc() {
  echo "🔧 Building bc ch6.15"
  rm -rf bc-*/ || true
  tar -xf bc-*.tar.*
  cd bc-*/

  cat > bc/fix-libmath_h << "EOF"
#! /bin/bash
sed -e '1   s/^/{"/' \
    -e     's/$/",/' \
    -e '2,$ s/^/"/'  \
    -e   '$ d'       \
    -i libmath.h

sed -e '$ s/$/0}/' \
    -i libmath.h
EOF

  ln -sv /tools/lib/libncursesw.so.6 /usr/lib/libncursesw.so.6
  ln -sfv libncursesw.so.6 /usr/lib/libncurses.so

  sed -i -e '/flex/s/as_fn_error/: ;; # &/' configure

  ./configure --prefix=/usr           \
            --with-readline         \
            --mandir=/usr/share/man \
            --infodir=/usr/share/info
  make
  make install

  cd /sources
  rm -rf bc-*/
}

build_binutils() {
  echo "🔧 Building binutils ch6.16"
  expect -c "spawn ls"
  rm -rf binutils-*/ || true
  tar -xf binutils-*.tar.*
  cd binutils-*/

  mkdir -v build
  cd       build

  ../configure --prefix=/usr       \
             --enable-gold       \
             --enable-ld=default \
             --enable-plugins    \
             --enable-shared     \
             --disable-werror    \
             --enable-64-bit-bfd \
             --with-system-zlib

  make tooldir=/usr
  make tooldir=/usr install

  cd /sources
  rm -rf binutils-*/
}

build_gmp() {
  echo "🔧 Building gmp ch6.17"
  rm -rf gmp-*/ || true
  tar -xf gmp-*.tar.*
  cd gmp-*/


  cp -v configfsf.guess config.guess
  cp -v configfsf.sub   config.sub

  ./configure --prefix=/usr    \
            --enable-cxx     \
            --disable-static \
            --docdir=/usr/share/doc/gmp-6.1.2

  make
  make html
  make check 2>&1 | tee gmp-check-log
  awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log

  make install
  make install-html

  cd /sources
  rm -rf gmp-*/
}

build_mpfr() {
  echo "🔧 Building mpfr ch6.18"
  rm -rf mpfr-*/ || true
  tar -xf mpfr-*.tar.*
  cd mpfr-*/

  ./configure --prefix=/usr        \
            --disable-static     \
            --enable-thread-safe \
            --docdir=/usr/share/doc/mpfr-4.0.2

  make
  make html
  make check
  make install
  make install-html

  cd /sources
  rm -rf mpfr-*/
}

build_mpc() {
  echo "🔧 Building mpc ch6.19"
  rm -rf mpc-*/ || true
  tar -xf mpc-*.tar.*
  cd mpc-*/

  ./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/mpc-1.1.0

  make
  make html
  make check
  make install
  make install-html

  cd /sources
  rm -rf mpc-*/
}

build_shadow() {
  echo "🔧 Building shadow ch6.20"
  rm -rf shadow-*/ || true
  tar -xf shadow-*.tar.*
  cd shadow-*/

  sed -i 's/groups$(EXEEXT) //' src/Makefile.in
  find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
  find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
  find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;

  sed -i -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD SHA512@' \
       -e 's@/var/spool/mail@/var/mail@' etc/login.defs

  sed -i 's/1000/999/' etc/useradd

  ./configure --sysconfdir=/etc --with-group-name-max-length=32

  make
  make install

  mv -v /usr/bin/passwd /bin

  pwconv
  grpconv
  sed -i 's/yes/no/' /etc/default/useradd

  cd /sources
  rm -rf shadow-*/
}

build_gcc() {
  echo "🔧 Building gcc ch6.21"
  rm -rf gcc-*/ || true
  tar -xf gcc-*.tar.*
  cd gcc-*/

  case $(uname -m) in
    x86_64)
      sed -e '/m64=/s/lib64/lib/' \
          -i.orig gcc/config/i386/t-linux64
    ;;
  esac

  rm -rf /usr/lib/gcc

  mkdir -v build
  cd       build

  SED=sed                               \
  ../configure --prefix=/usr            \
              --enable-languages=c,c++ \
              --disable-multilib       \
              --disable-bootstrap      \
              --disable-libmpx         \
              --with-system-zlib

  make
  ulimit -s 32768
  rm ../gcc/testsuite/g++.dg/pr83239.C

  set +e
  chown -Rv nobody .
  su nobody -s /bin/bash -c "PATH=$PATH make -k check"
  TEST_RC=$?
  set -e

  ../contrib/test_summary

  make install
  ln -sfv ../usr/bin/cpp /lib
  ln -sfv gcc /usr/bin/cc

  install -v -dm755 /usr/lib/bfd-plugins
  ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/8.2.0/liblto_plugin.so \
          /usr/lib/bfd-plugins/

  echo 'int main(){}' > dummy.c
  cc dummy.c -v -Wl,--verbose &> dummy.log
  readelf -l a.out | grep ': /lib'

  grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
  grep -B4 '^ /usr/include' dummy.log
  grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
  grep "/lib.*/libc.so.6 " dummy.log
  grep found dummy.log
  rm -v dummy.c a.out dummy.log

  mkdir -pv /usr/share/gdb/auto-load/usr/lib
  mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib

  cd /sources
  rm -rf gcc-*/
}

build_bzip2() {
  echo "🔧 Building bzip2 ch6.22"
  rm -rf bzip2-*/ || true
  tar -xf bzip2-*.tar.*
  cd bzip2-*/

  patch -Np1 -i ../bzip2-1.0.6-install_docs-1.patch
  sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
  sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile

  make -f Makefile-libbz2_so
  make clean

  make
  make PREFIX=/usr install

  cp -v bzip2-shared /bin/bzip2
  cp -av libbz2.so* /lib
  ln -sv ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so
  rm -v /usr/bin/{bunzip2,bzcat,bzip2}
  ln -sv bzip2 /bin/bunzip2
  ln -sv bzip2 /bin/bzcat

  cd /sources
  rm -rf bzip2-*/
}

build_pkg_config() {
  echo "🔧 Building pkg-config ch6.23"
  rm -rf pkg-config-*/ || true
  tar -xf pkg-config-*.tar.*
  cd pkg-config-*/

  ./configure --prefix=/usr              \
            --with-internal-glib       \
            --disable-host-tool        \
            --docdir=/usr/share/doc/pkg-config-0.29.2

  make
  make check
  make install

  cd /sources
  rm -rf pkg-config-*/
}

build_ncurses() {
  echo "🔧 Building ncurses ch6.24"
  rm -rf ncurses-*/ || true
  tar -xf ncurses-*.tar.*
  cd ncurses-*/

  sed -i '/LIBTOOL_INSTALL/d' c++/Makefile.in

  ./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            --with-shared           \
            --without-debug         \
            --without-normal        \
            --enable-pc-files       \
            --enable-widec

  make
  make install

  mv -v /usr/lib/libncursesw.so.6* /lib
  ln -sfv ../../lib/$(readlink /usr/lib/libncursesw.so) /usr/lib/libncursesw.so

  for lib in ncurses form panel menu ; do
      rm -vf                    /usr/lib/lib${lib}.so
      echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
      ln -sfv ${lib}w.pc        /usr/lib/pkgconfig/${lib}.pc
  done

  rm -vf                     /usr/lib/libcursesw.so
  echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so
  ln -sfv libncurses.so      /usr/lib/libcurses.so

  mkdir -v       /usr/share/doc/ncurses-6.1
  cp -v -R doc/* /usr/share/doc/ncurses-6.1

  make distclean
  ./configure --prefix=/usr    \
              --with-shared    \
              --without-normal \
              --without-debug  \
              --without-cxx-binding \
              --with-abi-version=5
  make sources libs
  cp -av lib/lib*.so.5* /usr/lib

  cd /sources
  rm -rf ncurses-*/
}

build_attr() {
  echo "🔧 Building attr ch6.25"
  rm -rf attr-*/ || true
  tar -xf attr-*.tar.*
  cd attr-*/

  ./configure --prefix=/usr     \
            --bindir=/bin     \
            --disable-static  \
            --sysconfdir=/etc \
            --docdir=/usr/share/doc/attr-2.4.48

  make
  make check
  make install

  mv -v /usr/lib/libattr.so.* /lib
  ln -sfv ../../lib/$(readlink /usr/lib/libattr.so) /usr/lib/libattr.so

  cd /sources
  rm -rf attr-*/
}

build_acl() {
  echo "🔧 Building acl ch6.26"
  rm -rf acl-*/ || true
  tar -xf acl-*.tar.*
  cd acl-*/

  ./configure --prefix=/usr         \
            --bindir=/bin         \
            --disable-static      \
            --libexecdir=/usr/lib \
            --docdir=/usr/share/doc/acl-2.2.53

  make
  make install

  mv -v /usr/lib/libacl.so.* /lib
  ln -sfv ../../lib/$(readlink /usr/lib/libacl.so) /usr/lib/libacl.so

  cd /sources
  rm -rf acl-*/
}

build_libcap() {
  echo "🔧 Building libcap ch6.27"
  rm -rf libcap-*/ || true
  tar -xf libcap-*.tar.*
  cd libcap-*/

  sed -i '/install.*STALIBNAME/d' libcap/Makefile

  make
  make RAISE_SETFCAP=no lib=lib prefix=/usr install
  chmod -v 755 /usr/lib/libcap.so.2.26

  mv -v /usr/lib/libcap.so.* /lib
  ln -sfv ../../lib/$(readlink /usr/lib/libcap.so) /usr/lib/libcap.so

  cd /sources
  rm -rf libcap-*/
}

build_sed() {
  echo "🔧 Building sed ch6.28"
  rm -rf sed-*/ || true
  tar -xf sed-*.tar.*
  cd sed-*/

  sed -i 's/usr/tools/'                 build-aux/help2man
  sed -i 's/testsuite.panic-tests.sh//' Makefile.in

  ./configure --prefix=/usr --bindir=/bin

  make
  make html
  make check
  make install
  install -d -m755           /usr/share/doc/sed-4.7
  install -m644 doc/sed.html /usr/share/doc/sed-4.7

  cd /sources
  rm -rf sed-*/
}

build_psmisc() {
  echo "🔧 Building psmisc ch6.29"
  rm -rf psmisc-*/ || true
  tar -xf psmisc-*.tar.*
  cd psmisc-*/

  ./configure --prefix=/usr

  make
  make install

  mv -v /usr/bin/fuser   /bin
  mv -v /usr/bin/killall /bin

  cd /sources
  rm -rf psmisc-*/
}

build_iana_etc() {
  echo "🔧 Building iana-etc ch6.30"
  rm -rf iana-etc-*/ || true
  tar -xf iana-etc-*.tar.*
  cd iana-etc-*/

  make
  make install

  cd /sources
  rm -rf iana-etc-*/
}

build_bison() {
  echo "🔧 Building bison ch6.31"
  rm -rf bison-*/ || true
  tar -xf bison-*.tar.*
  cd bison-*/

  ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.3.2

  make
  make install

  cd /sources
  rm -rf bison-*/
}

build_flex() {
  echo "🔧 Building flex ch6.32"
  rm -rf flex-*/ || true
  tar -xf flex-*.tar.*
  cd flex-*/

  sed -i "/math.h/a #include <malloc.h>" src/flexdef.h
  HELP2MAN=/tools/bin/true \
  ./configure --prefix=/usr --docdir=/usr/share/doc/flex-2.6.4

  make
  make install

  ln -sv flex /usr/bin/lex

  cd /sources
  rm -rf flex-*/
}

build_grep() {
  echo "🔧 Building grep ch6.33"
  rm -rf grep-*/ || true
  tar -xf grep-*.tar.*
  cd grep-*/

  ./configure --prefix=/usr --bindir=/bin

  make
  make -k check
  make install

  cd /sources
  rm -rf grep-*/
}

build_bash() {
  echo "🔧 Building bash ch6.34"
  rm -rf bash-*/ || true
  tar -xf bash-*.tar.*
  cd bash-*/

  ./configure --prefix=/usr                    \
            --docdir=/usr/share/doc/bash-5.0 \
            --without-bash-malloc            \
            --with-installed-readline

  make
  chown -Rv nobody .
  su nobody -s /bin/bash -c "PATH=$PATH HOME=/home make tests"
  make install
  mv -vf /usr/bin/bash /bin

  cd /sources
  rm -rf bash-*/
}

build_libtool() {
  echo "🔧 Building libtool ch6.35"
  rm -rf libtool-*/ || true
  tar -xf libtool-*.tar.*
  cd libtool-*/

  ./configure --prefix=/usr

  make

  # NOTE: because of circular dependency issues with automake, some tests will fail, so we ignore errors here
  set +e
  make check
  set -e
  make install

  cd /sources
  rm -rf libtool-*/
}

build_gdbm() {
  echo "🔧 Building gdbm ch6.36"
  rm -rf gdbm-*/ || true
  tar -xf gdbm-*.tar.*
  cd gdbm-*/

  ./configure --prefix=/usr    \
            --disable-static \
            --enable-libgdbm-compat

  make
  make check
  make install

  cd /sources
  rm -rf gdbm-*/
}

build_gperf() {
  echo "🔧 Building gperf ch6.37"
  rm -rf gperf-*/ || true
  tar -xf gperf-*.tar.*
  cd gperf-*/

  ./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.1

  make
  make -j1 check
  make install

  cd /sources
  rm -rf gperf-*/
}

build_expat() {
  echo "🔧 Building expat ch6.38"
  rm -rf expat-*/ || true
  tar -xf expat-*.tar.*
  cd expat-*/

  sed -i 's|usr/bin/env |bin/|' run.sh.in

  ./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/expat-2.2.6

  make
  make check
  make install
  install -v -m644 doc/*.{html,png,css} /usr/share/doc/expat-2.2.6

  cd /sources
  rm -rf expat-*/
}

build_inetutils() {
  echo "🔧 Building inetutils ch6.39"
  rm -rf inetutils-*/ || true
  tar -xf inetutils-*.tar.*
  cd inetutils-*/

  ./configure --prefix=/usr        \
            --localstatedir=/var \
            --disable-logger     \
            --disable-whois      \
            --disable-rcp        \
            --disable-rexec      \
            --disable-rlogin     \
            --disable-rsh        \
            --disable-servers

  make
  make check
  make install

  mv -v /usr/bin/{hostname,ping,ping6,traceroute} /bin
  mv -v /usr/bin/ifconfig /sbin

  cd /sources
  rm -rf inetutils-*/
}

build_perl() {
  echo "🔧 Building perl ch6.40"
  rm -rf perl-*/ || true
  tar -xf perl-*.tar.*
  cd perl-*/

  echo "127.0.0.1 localhost $(hostname)" > /etc/hosts
  export BUILD_ZLIB=False
  export BUILD_BZIP2=0

  sh Configure -des -Dprefix=/usr                 \
                  -Dvendorprefix=/usr           \
                  -Dman1dir=/usr/share/man/man1 \
                  -Dman3dir=/usr/share/man/man3 \
                  -Dpager="/usr/bin/less -isR"  \
                  -Duseshrplib                  \
                  -Dusethreads

  make
  set +e
  make -k test
  set -e

  make install
  unset BUILD_ZLIB BUILD_BZIP2

  cd /sources
  rm -rf perl-*/
}

build_xml_parser() {
  echo "🔧 Building XML::Parser ch6.41"
  rm -rf XML-Parser-*/ || true
  tar -xf XML-Parser-*.tar.*
  cd XML-Parser-*/

  perl Makefile.PL
  make
  make test
  make install

  cd /sources
  rm -rf XML-Parser-*/
}

build_intltool() {
  echo "🔧 Building intltool ch6.42"
  rm -rf intltool-*/ || true
  tar -xf intltool-*.tar.*
  cd intltool-*/

  sed -i 's:\\\${:\\\$\\{:' intltool-update.in

  ./configure --prefix=/usr

  make
  make check
  make install
  install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO

  cd /sources
  rm -rf intltool-*/
}

build_autoconf() {
  echo "🔧 Building autoconf ch6.43"
  rm -rf autoconf-*/ || true
  tar -xf autoconf-*.tar.*
  cd autoconf-*/

  sed '361 s/{/\\{/' -i bin/autoscan.in

  ./configure --prefix=/usr

  make
  # NOTE: because of bash-5.0 and the libtool issue, some tests will fail, so we ignore errors here
  # make check
  make install

  cd /sources
  rm -rf autoconf-*/
}

build_automake() {
  echo "🔧 Building automake ch6.44"
  rm -rf automake-*/ || true
  tar -xf automake-*.tar.*
  cd automake-*/

  ./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.16.1

  make
  # NOTE: here is one failed test as known issue, so we ignore errors here
  set +e
  make -j4 check
  set -e
  make install

  cd /sources
  rm -rf automake-*/
}

build_xz() {
  echo "🔧 Building xz ch6.45"
  rm -rf xz-*/ || true
  tar -xf xz-*.tar.*
  cd xz-*/

  ./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/xz-5.2.4

  make
  make check
  make install
  mv -v   /usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} /bin
  mv -v /usr/lib/liblzma.so.* /lib
  ln -svf ../../lib/$(readlink /usr/lib/liblzma.so) /usr/lib/liblzma.so

  cd /sources
  rm -rf xz-*/
}

build_kmod() {
  echo "🔧 Building kmod ch6.46"
  rm -rf kmod-*/ || true
  tar -xf kmod-*.tar.*
  cd kmod-*/

  ./configure --prefix=/usr          \
            --bindir=/bin          \
            --sysconfdir=/etc      \
            --with-rootlibdir=/lib \
            --with-xz              \
            --with-zlib

  make
  make install

  for target in depmod insmod lsmod modinfo modprobe rmmod; do
    ln -sfv ../bin/kmod /sbin/$target
  done

  ln -sfv kmod /bin/lsmod

  cd /sources
  rm -rf kmod-*/
}

build_gettext() {
  echo "🔧 Building gettext ch6.47"
  rm -rf gettext-*/ || true
  tar -xf gettext-*.tar.*
  cd gettext-*/

  sed -i '/^TESTS =/d' gettext-runtime/tests/Makefile.in &&
  sed -i 's/test-lock..EXEEXT.//' gettext-tools/gnulib-tests/Makefile.in

  sed -e '/AppData/{N;N;p;s/\.appdata\./.metainfo./}' \
    -i gettext-tools/its/appdata.loc

  ./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/gettext-0.19.8.1

  make
  make check
  make install
  chmod -v 0755 /usr/lib/preloadable_libintl.so

  cd /sources
  rm -rf gettext-*/
}

build_elfutils() {
  echo "🔧 Building elfutils ch6.48"
  rm -rf elfutils-*/ || true
  tar -xf elfutils-*.tar.*
  cd elfutils-*/

  ./configure --prefix=/usr

  make
  make check
  make -C libelf install
  install -vm644 config/libelf.pc /usr/lib/pkgconfig

  cd /sources
  rm -rf elfutils-*/
}

build_libffi() {
  echo "🔧 Building libffi ch6.49"
  rm -rf libffi-*/ || true
  tar -xf libffi-*.tar.*
  cd libffi-*/

  sed -e '/^includesdir/ s/$(libdir).*$/$(includedir)/' \
    -i include/Makefile.in

  sed -e '/^includedir/ s/=.*$/=@includedir@/' \
      -e 's/^Cflags: -I${includedir}/Cflags:/' \
      -i libffi.pc.in

  ./configure --prefix=/usr --disable-static --with-gcc-arch=native

  make
  make check
  make install

  cd /sources
  rm -rf libffi-*/
}

build_openssl() {
  echo "🔧 Building openssl ch6.50"
  rm -rf openssl-*/ || true
  tar -xf openssl-*.tar.*
  cd openssl-*/

  ./config --prefix=/usr         \
         --openssldir=/etc/ssl \
         --libdir=lib          \
         shared                \
         zlib-dynamic

  make
  # make test
  sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
  make MANSUFFIX=ssl install

  mv -v /usr/share/doc/openssl /usr/share/doc/openssl-1.1.1a
  cp -vfr doc/* /usr/share/doc/openssl-1.1.1a

  cd /sources
  rm -rf openssl-*/
}

build_python() {
  echo "🔧 Building python ch6.51"
  rm -rf Python-*/ || true
  tar -xf Python-*.tar.*
  cd Python-*/

  ./configure --prefix=/usr       \
            --enable-shared     \
            --with-system-expat \
            --with-system-ffi   \
            --with-ensurepip=yes

  make
  make install
  chmod -v 755 /usr/lib/libpython3.7m.so
  chmod -v 755 /usr/lib/libpython3.so

  install -v -dm755 /usr/share/doc/python-3.7.2/html

  tar --strip-components=1  \
      --no-same-owner       \
      --no-same-permissions \
      -C /usr/share/doc/python-3.7.2/html \
      -xvf ../python-3.7.2-docs-html.tar.bz2

  cd /sources
  rm -rf Python-*/
}

build_ninja() {
  echo "🔧 Building ninja ch6.52"
  rm -rf ninja-*/ || true
  tar -xf ninja-*.tar.*
  cd ninja-*/

  export NINJAJOBS=4
  sed -i '/int Guess/a \
    int   j = 0;\
    char* jobs = getenv( "NINJAJOBS" );\
    if ( jobs != NULL ) j = atoi( jobs );\
    if ( j > 0 ) return j;\
  ' src/ninja.cc

  python3 configure.py --bootstrap

  python3 configure.py
  ./ninja ninja_test
  ./ninja_test --gtest_filter=-SubprocessTest.SetWithLots

  install -vm755 ninja /usr/bin/
  install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
  install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja

  cd /sources
  rm -rf ninja-*/
}

build_meson() {
  echo "🔧 Building meson ch6.53"
  rm -rf meson-*/ || true
  tar -xf meson-*.tar.*
  cd meson-*/

  python3 setup.py build
  python3 setup.py install --root=dest
  cp -rv dest/* /

  cd /sources
  rm -rf meson-*/
}

build_coreutils() {
  echo "🔧 Building coreutils ch6.54"
  rm -rf coreutils-*/ || true
  tar -xf coreutils-*.tar.*
  cd coreutils-*/

  patch -Np1 -i ../coreutils-8.30-i18n-1.patch
  sed -i '/test.lock/s/^/#/' gnulib-tests/gnulib.mk

  autoreconf -fiv
  FORCE_UNSAFE_CONFIGURE=1 ./configure \
              --prefix=/usr            \
              --enable-no-install-program=kill,uptime

  FORCE_UNSAFE_CONFIGURE=1 make
  make install

  mv -v /usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} /bin
  mv -v /usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} /bin
  mv -v /usr/bin/{rmdir,stty,sync,true,uname} /bin
  mv -v /usr/bin/chroot /usr/sbin
  mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
  sed -i s/\"1\"/\"8\"/1 /usr/share/man/man8/chroot.8

  mv -v /usr/bin/{head,nice,sleep,touch} /bin

  cd /sources
  rm -rf coreutils-*/
}

build_check() {
  echo "🔧 Building check ch6.55"
  rm -rf check-*/ || true
  tar -xf check-*.tar.*
  cd check-*/

  ./configure --prefix=/usr

  make
  make check
  make install
  sed -i '1 s/tools/usr/' /usr/bin/checkmk

  cd /sources
  rm -rf check-*/
}

build_diffutils() {
  echo "🔧 Building diffutils ch6.11"
  rm -rf diffutils-*/ || true
  tar -xf diffutils-*.tar.*
  cd diffutils-*/

  ./configure --prefix=/usr

  make
  make check
  make install

  cd /sources
  rm -rf diffutils-*/
}

build_gawk() {
  echo "🔧 Building gawk ch6.12"
  rm -rf gawk-*/ || true
  tar -xf gawk-*.tar.*
  cd gawk-*/

  sed -i 's/extras//' Makefile.in
  ./configure --prefix=/usr

  make
  make check
  make install

  mkdir -v /usr/share/doc/gawk-4.2.1
  cp    -v doc/{awkforai.txt,*.{eps,pdf,jpg}} /usr/share/doc/gawk-4.2.1

  cd /sources
  rm -rf gawk-*/
}

build_findutils() {
  echo "🔧 Building findutils ch6.58"
  rm -rf findutils-*/ || true
  tar -xf findutils-*.tar.*
  cd findutils-*/

  sed -i 's/test-lock..EXEEXT.//' tests/Makefile.in

  sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' gl/lib/*.c
  sed -i '/unistd/a #include <sys/sysmacros.h>' gl/lib/mountlist.c
  echo "#define _IO_IN_BACKUP 0x100" >> gl/lib/stdio-impl.h

  ./configure --prefix=/usr --localstatedir=/var/lib/locate

  make
  make check
  make install

  mv -v /usr/bin/find /bin
  sed -i 's|find:=${BINDIR}|find:=/bin|' /usr/bin/updatedb

  cd /sources
  rm -rf findutils-*/
}

build_groff() {
  echo "🔧 Building groff ch6.59"
  rm -rf groff-*/ || true
  tar -xf groff-*.tar.*
  cd groff-*/

  PAGE=A4 ./configure --prefix=/usr

  make -j1
  make install

  cd /sources
  rm -rf groff-*/
}

build_grub() {
  echo "🔧 Building grub ch6.60"
  rm -rf grub-*/ || true
  tar -xf grub-*.tar.*
  cd grub-*/

  ./configure --prefix=/usr          \
            --sbindir=/sbin        \
            --sysconfdir=/etc      \
            --disable-efiemu       \
            --disable-werror

  make
  make install
  mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions

  cd /sources
  rm -rf grub-*/
}

build_less() {
  echo "🔧 Building less ch6.61"
  rm -rf less-*/ || true
  tar -xf less-*.tar.*
  cd less-*/

  ./configure --prefix=/usr --sysconfdir=/etc

  make
  make install

  cd /sources
  rm -rf less-*/
}

build_gzip() {
  echo "🔧 Building gzip ch6.62"
  rm -rf gzip-*/ || true
  tar -xf gzip-*.tar.*
  cd gzip-*/

  ./configure --prefix=/usr

  make
  # NOTE: gzip test suite fails sometimes, so we ignore errors here
  set +e
  make check
  set -e
  make install
  mv -v /usr/bin/gzip /bin

  cd /sources
  rm -rf gzip-*/
}

build_iproute2() {
  echo "🔧 Building iproute2 ch6.63"
  rm -rf iproute2-*/ || true
  tar -xf iproute2-*.tar.*
  cd iproute2-*/

  sed -i /ARPD/d Makefile
  rm -fv man/man8/arpd.8
  sed -i 's/.m_ipt.o//' tc/Makefile

  make
  make DOCDIR=/usr/share/doc/iproute2-4.20.0 install

  cd /sources
  rm -rf iproute2-*/
}

build_kbd() {
  echo "🔧 Building kbd ch6.64"
  rm -rf kbd-*/ || true
  tar -xf kbd-*.tar.*
  cd kbd-*/

  patch -Np1 -i ../kbd-2.0.4-backspace-1.patch

  sed -i 's/\(RESIZECONS_PROGS=\)yes/\1no/g' configure
  sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in

  PKG_CONFIG_PATH=/tools/lib/pkgconfig ./configure --prefix=/usr --disable-vlock

  make
  make check
  make install

  mkdir -v       /usr/share/doc/kbd-2.0.4
  cp -R -v docs/doc/* /usr/share/doc/kbd-2.0.4

  cd /sources
  rm -rf kbd-*/
}

build_libpipeline() {
  echo "🔧 Building libpipeline ch6.65"
  rm -rf libpipeline-*/ || true
  tar -xf libpipeline-*.tar.*
  cd libpipeline-*/

  ./configure --prefix=/usr

  make
  make check
  make install

  cd /sources
  rm -rf libpipeline-*/
}

build_make() {
  echo "🔧 Building make ch6.66"
  rm -rf make-*/ || true
  tar -xf make-*.tar.*
  cd make-*/

  sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c

  ./configure --prefix=/usr

  make
  make PERL5LIB=$PWD/tests/ check
  make install

  cd /sources
  rm -rf make-*/
}

build_patch() {
  echo "🔧 Building patch ch6.67"
  rm -rf patch-*/ || true
  tar -xf patch-*.tar.*
  cd patch-*/

  ./configure --prefix=/usr

  make
  make check
  make install

  cd /sources
  rm -rf patch-*/
}

build_man_db() {
  echo "🔧 Building Man-DB ch6.68"
  rm -rf man-db-*/ || true
  tar -xf man-db-*.tar.*
  cd man-db-*/

  ./configure --prefix=/usr                        \
            --docdir=/usr/share/doc/man-db-2.8.5 \
            --sysconfdir=/etc                    \
            --disable-setuid                     \
            --enable-cache-owner=bin             \
            --with-browser=/usr/bin/lynx         \
            --with-vgrind=/usr/bin/vgrind        \
            --with-grap=/usr/bin/grap            \
            --with-systemdtmpfilesdir=           \
            --with-systemdsystemunitdir=

  make
  make check
  make install

  cd /sources
  rm -rf man-db-*/
}

build_tar() {
  echo "🔧 Building tar ch6.69"
  rm -rf tar-*/ || true
  tar -xf tar-*.tar.*
  cd tar-*/

  sed -i 's/abort.*/FALLTHROUGH;/' src/extract.c

  FORCE_UNSAFE_CONFIGURE=1  \
  ./configure --prefix=/usr \
              --bindir=/bin

  make
  # NOTE: tar test suite fails sometimes, so we ignore errors here
  set +e
  make check
  set -e
  make install
  make -C doc install-html docdir=/usr/share/doc/tar-1.31

  cd /sources
  rm -rf tar-*/
}

build_texinfo() {
  echo "🔧 Building texinfo ch6.70"
  rm -rf texinfo-*/ || true
  tar -xf texinfo-*.tar.*
  cd texinfo-*/

  sed -i '5481,5485 s/({/(\\{/' tp/Texinfo/Parser.pm

  ./configure --prefix=/usr --disable-static

  make
  make check
  make install

  cd /sources
  rm -rf texinfo-*/
}

build_vim() {
  echo "🔧 Building vim ch6.71"
  rm -rf vim-*/ || true
  tar -xf vim-*.tar.*
  cd vim*/

  echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h

  ./configure --prefix=/usr

  make
  LANG=en_US.UTF-8 make -j1 test &> vim-test.log
  make install

  ln -sv vim /usr/bin/vi
  for L in  /usr/share/man/{,*/}man1/vim.1; do
      ln -sv vim.1 $(dirname $L)/vi.1
  done

  ln -sv ../vim/vim81/doc /usr/share/doc/vim-8.1

  cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1

set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF

  cd /sources
  rm -rf vim-*/
}

build_procps() {
  echo "🔧 Building procps ch6.72"
  rm -rf procps-*/ || true
  tar -xf procps-*.tar.*
  cd procps-*/

  ./configure --prefix=/usr                            \
            --exec-prefix=                           \
            --libdir=/usr/lib                        \
            --docdir=/usr/share/doc/procps-ng-3.3.15 \
            --disable-static                         \
            --disable-kill

  make
  sed -i -r 's|(pmap_initname)\\\$|\1|' testsuite/pmap.test/pmap.exp
  sed -i '/set tty/d' testsuite/pkill.test/pkill.exp
  rm testsuite/pgrep.test/pgrep.exp
  make check
  make install

  mv -v /usr/lib/libprocps.so.* /lib
  ln -sfv ../../lib/$(readlink /usr/lib/libprocps.so) /usr/lib/libprocps.so

  cd /sources
  rm -rf procps-*/
}

build_util_linux() {
  echo "🔧 Building util-linux ch6.73"
  rm -rf util-linux-*/ || true
  tar -xf util-linux-*.tar.*
  cd util-linux-*/

  mkdir -pv /var/lib/hwclock
  rm -vf /usr/include/{blkid,libmount,uuid}

  ./configure ADJTIME_PATH=/var/lib/hwclock/adjtime   \
            --docdir=/usr/share/doc/util-linux-2.33.1 \
            --disable-chfn-chsh  \
            --disable-login      \
            --disable-nologin    \
            --disable-su         \
            --disable-setpriv    \
            --disable-runuser    \
            --disable-pylibmount \
            --disable-static     \
            --without-python     \
            --without-systemd    \
            --without-systemdsystemunitdir

  make
  make install

  cd /sources
  rm -rf util-linux-*/
}

build_e2fsprogs() {
  echo "🔧 Building e2fsprogs ch6.74"
  rm -rf e2fsprogs-*/ || true
  tar -xf e2fsprogs-*.tar.*
  cd e2fsprogs-*/

  mkdir -v build
  cd       build

  ../configure --prefix=/usr           \
             --bindir=/bin           \
             --with-root-prefix=""   \
             --enable-elf-shlibs     \
             --disable-libblkid      \
             --disable-libuuid       \
             --disable-uuidd         \
             --disable-fsck

  make
  make check
  make install
  make install-libs

  chmod -v u+w /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
  gunzip -v /usr/share/info/libext2fs.info.gz
  install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info

  cd /sources
  rm -rf e2fsprogs-*/
}

build_sysklogd() {
  echo "🔧 Building sysklogd ch6.75"
  rm -rf sysklogd-*/ || true
  tar -xf sysklogd-*.tar.*
  cd sysklogd-*/

  sed -i '/Error loading kernel symbols/{n;n;d}' ksym_mod.c
  sed -i 's/union wait/int/' syslogd.c

  make
  make BINDIR=/sbin install

  cat > /etc/syslog.conf << "EOF"
# Begin /etc/syslog.conf

auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/sys.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *

# End /etc/syslog.conf
EOF

  cd /sources
  rm -rf sysklogd-*/
}

build_sysvinit() {
  echo "🔧 Building sysvinit ch6.76"
  rm -rf sysvinit-*/ || true
  tar -xf sysvinit-*.tar.*
  cd sysvinit-*/

  patch -Np1 -i ../sysvinit-2.93-consolidated-1.patch

  make
  make install

  cd /sources
  rm -rf sysvinit-*/
}

build_eudev() {
  echo "🔧 Building eudev ch6.77"
  rm -rf eudev-*/ || true
  tar -xf eudev-*.tar.*
  cd eudev-*/

  cat > config.cache << "EOF"
HAVE_BLKID=1
BLKID_LIBS="-lblkid"
BLKID_CFLAGS="-I/tools/include"
EOF

  ./configure --prefix=/usr           \
            --bindir=/sbin          \
            --sbindir=/sbin         \
            --libdir=/usr/lib       \
            --sysconfdir=/etc       \
            --libexecdir=/lib       \
            --with-rootprefix=      \
            --with-rootlibdir=/lib  \
            --enable-manpages       \
            --disable-static        \
            --config-cache

  LIBRARY_PATH=/tools/lib make

  mkdir -pv /lib/udev/rules.d
  mkdir -pv /etc/udev/rules.d
  make LD_LIBRARY_PATH=/tools/lib check
  make LD_LIBRARY_PATH=/tools/lib install

  tar -xvf ../udev-lfs-20171102.tar.bz2
  make -f udev-lfs-20171102/Makefile.lfs install

  LD_LIBRARY_PATH=/tools/lib udevadm hwdb --update

  cd /sources
  rm -rf eudev-*/
}

clean_up() {
  echo "🧹 Cleaning up files ch6.80"

  rm -rf /tmp/*

  rm -f /usr/lib/lib{bfd,opcodes}.a
  rm -f /usr/lib/libbz2.a
  rm -f /usr/lib/lib{com_err,e2p,ext2fs,ss}.a
  rm -f /usr/lib/libltdl.a
  rm -f /usr/lib/libfl.a
  rm -f /usr/lib/libz.a

  echo "📝 Marking chroot as revised"
  touch /etc/.revised-chroot
}

# ===== execute in order (rerunnable) =====
echo "🚀 Starting ch6 build process"

# ensure_binutils_symlinks
debug_toolchain_snapshot
run_step dirs          create_dirs
run_step symlinks      create_symlinks
run_step passwd_group  create_passwd_group
run_step var_logs      init_var_log_files
# ----------
cd /sources
run_step linux_headers build_linux_headers
run_step manpages      build_manpages
run_step glibc         build_glibc
run_step toolchain     adjust_toolchain
run_step zlib          build_zlib
run_step file          build_file
run_step readline      build_readline
run_step m4            build_m4
run_step bc            build_bc
run_step binutils      build_binutils
run_step gmp           build_gmp
run_step mpfr          build_mpfr
run_step mpc           build_mpc
run_step shadow        build_shadow
run_step gcc           build_gcc
run_step bzip2         build_bzip2
run_step pkg_config    build_pkg_config
run_step ncurses       build_ncurses
run_step attr          build_attr
run_step acl           build_acl
run_step libcap        build_libcap
run_step sed           build_sed
run_step psmisc        build_psmisc
run_step iana_etc      build_iana_etc
run_step bison         build_bison
run_step flex          build_flex
run_step grep          build_grep
run_step bash          build_bash
run_step libtool       build_libtool
run_step gdbm          build_gdbm
run_step gperf         build_gperf
run_step expat         build_expat
run_step inetutils     build_inetutils
run_step perl          build_perl
run_step xml_parser    build_xml_parser
run_step intltool      build_intltool
run_step autoconf      build_autoconf
run_step automake      build_automake
run_step xz            build_xz
run_step kmod          build_kmod
run_step gettext       build_gettext
run_step elfutils      build_elfutils
run_step libffi        build_libffi
run_step openssl       build_openssl
run_step python        build_python
run_step ninja         build_ninja
run_step meson         build_meson
run_step coreutils     build_coreutils
run_step check         build_check
run_step diffutils     build_diffutils
run_step gawk          build_gawk
run_step findutils     build_findutils
run_step groff         build_groff
run_step grub          build_grub
run_step less          build_less
run_step gzip          build_gzip
run_step iproute2      build_iproute2
run_step kbd           build_kbd
run_step libpipeline   build_libpipeline
run_step make          build_make
run_step patch         build_patch
run_step man-db        build_man_db
run_step tar           build_tar
run_step texinfo       build_texinfo
run_step vim           build_vim
run_step procps        build_procps
run_step util_linux    build_util_linux
run_step e2fsprogs     build_e2fsprogs
run_step sysklogd      build_sysklogd
run_step sysvinit      build_sysvinit
run_step eudev         build_eudev

run_step cleanup       clean_up

echo "🎉 ch6 done"
