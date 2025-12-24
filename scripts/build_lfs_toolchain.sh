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
  rm -rf /tmp/linux-* || true
  tar -xf /sources/linux-*.tar.* -C /tmp/
  cd /tmp/linux-*/

  make mrproper
  make INSTALL_HDR_PATH=dest headers_install
  find dest/include \( -name .install -o -name ..install.cmd \) -delete
  cp -rv dest/include/* /usr/include

  cd /
  rm -rf /tmp/linux-*/
}

build_manpages() {
  echo "🔧 Building man-pages ch6.8"
  rm -rf /tmp/man-pages-* || true
  tar -xf /tmp/man-pages-*.tar.* -C /tmp/
  cd /tmp/man-pages-*/

  make install
  cd /
  rm -rf /tmp/man-pages-*/
}

build_glibc() {
  echo "🔧 Building glibc ch6.9"
  rm -rf /tmp/glibc-* || true
  tar -xf /sources/glibc-*.tar.* -C /tmp/
  cd /tmp/glibc-*/

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

  make check
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

  cd /
  rm -rf /tmp/glibc-*/
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
  rm -rf /tmp/zlib-* || true
  tar -xf /sources/zlib-*.tar.* -C /tmp/
  cd /tmp/zlib-*/

  ./configure --prefix=/usr
  make
  make check
  make install

  mv -v /usr/lib/libz.so.* /lib
  ln -sfv ../../lib/$(readlink /usr/lib/libz.so) /usr/lib/libz.so

  cd /
  rm -rf /tmp/zlib-*/
}

build_file() {
  echo "🔧 Building file ch6.12"
  rm -rf /tmp/file-* || true
  tar -xf /sources/file-*.tar.* -C /tmp/
  cd /tmp/file-*/

  ./configure --prefix=/usr
  make
  make check
  make install

  cd /
  rm -rf /tmp/file-*/
}

build_readline() {
  echo "🔧 Building readline ch6.13"
  rm -rf /tmp/readline-* || true
  tar -xf /sources/readline-*.tar.* -C /tmp/
  cd /tmp/readline-*/

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
}

# ===== execute in order (rerunnable) =====
run_step dirs          create_dirs
run_step symlinks      create_symlinks
run_step passwd_group  create_passwd_group
run_step var_logs      init_var_log_files
# ----------
run_step linux_headers build_linux_headers
run_step manpages      build_manpages
run_step glibc         build_glibc
run_step toolchain     adjust_toolchain
run_step zlib          build_zlib
run_step file          build_file
run_step readline      build_readline

echo "🎉 ch6.5~6.7 done."
