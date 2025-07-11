#!/bin/bash
set -e

export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin

echo "🧱 Verifying compiler produces working binaries..."
echo "int main(){}" > dummy.c
/tools/bin/${LFS_TGT}-gcc dummy.c -o dummy || {
  echo "❌ GCC cannot compile basic binary – something is broken."
  exit 1
}
rm dummy dummy.c

echo "🧱 Building LFS system..."

# Building the LFS core system follow the LFS Chapter 6 instructions.
./scripts/lfs_core/pkg_flex.sh
./scripts/lfs_core/pkg_binutils_pass2.sh
# ./scripts/lfs_core/pkg_gcc_pass2.sh
# ./scripts/lfs_core/pkg_bash.sh
# ./scripts/lfs_core/pkg_coreutils.sh
# ./scripts/lfs_core/pkg_make.sh
# etc...

echo "✅ LFS base system done."
