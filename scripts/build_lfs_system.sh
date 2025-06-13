#!/bin/bash
set -e

echo "🧱 Building LFS system..."

# Building the LFS core system follow the LFS Chapter 6 instructions.
./scripts/lfs_core/pkg_binutils_pass2.sh
# ./scripts/lfs_core/pkg_gcc_pass2.sh
# ./scripts/lfs_core/pkg_bash.sh
# ./scripts/lfs_core/pkg_coreutils.sh
# ./scripts/lfs_core/pkg_make.sh
# etc...

echo "✅ LFS base system done."
