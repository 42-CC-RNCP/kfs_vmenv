#!/bin/bash
# =============================================================================
# BLFS 8.4 Modular Build Script
# 
# RUN ON: Chroot (via chroot_exec in build_all.sh)
# PURPOSE: Build BLFS packages in dependency order
#
# To add a new package:
#   1. Add URL to config/blfs-wget-list.txt
#   2. Add build function: build_<pkgname>()
#   3. Add to BLFS_PACKAGES array
# =============================================================================
set -eEuo pipefail

echo "🔧 BLFS 8.4 Package Builder"
echo "==========================================="

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
BLFS_SOURCES="/sources/blfs"
STAMP_DIR="/.kfs/stamps/blfs"
MAKEFLAGS="${MAKEFLAGS:--j$(nproc)}"

mkdir -p "$STAMP_DIR"

# -----------------------------------------------------------------------------
# Package build order
# Add new packages here (must match build_<name> function)
# -----------------------------------------------------------------------------
BLFS_PACKAGES=(
    wget
    vim
)

# -----------------------------------------------------------------------------
# Helper: rerunnable step execution
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# Helper: find tarball by package name pattern
# -----------------------------------------------------------------------------
find_tarball() {
  local pattern="$1"
  local found
  found=$(find "$BLFS_SOURCES" -maxdepth 1 -name "${pattern}-*.tar.*" -o -name "${pattern}[0-9]*.tar.*" 2>/dev/null | head -n1)
  echo "$found"
}

# -----------------------------------------------------------------------------
# Helper: extract version from tarball name
# -----------------------------------------------------------------------------
get_version() {
  local tarball="$1"
  local base
  base=$(basename "$tarball")
  # Remove .tar.* extension, then extract version
  base="${base%.tar.*}"
  echo "${base#*-}"
}

# =============================================================================
# PACKAGE BUILD FUNCTIONS
# =============================================================================

build_wget() {
  local tarball
  tarball=$(find_tarball "wget")
  
  if [[ -z "$tarball" || ! -f "$tarball" ]]; then
    echo "❌ wget tarball not found in $BLFS_SOURCES"
    return 1
  fi
  
  local ver
  ver=$(get_version "$tarball")
  echo "Building wget-$ver ..."
  
  cd "$BLFS_SOURCES"
  rm -rf "wget-$ver"
  tar -xf "$tarball"
  cd "wget-$ver"
  
  ./configure --prefix=/usr      \
              --sysconfdir=/etc  \
              --with-ssl=openssl
  
  make $MAKEFLAGS
  make install
  
  # Configure CA certificates
  if [[ -d /etc/ssl/certs ]]; then
    grep -q "ca-directory" /etc/wgetrc 2>/dev/null || \
      echo "ca-directory=/etc/ssl/certs" >> /etc/wgetrc
  fi
  
  cd "$BLFS_SOURCES"
  rm -rf "wget-$ver"
  
  echo "Installed: $(wget --version | head -n1)"
}

# -----------------------------------------------------------------------------
# Vim
# Ref: http://www.linuxfromscratch.org/blfs/view/8.4/postlfs/vim.html
# Note: vim tarball extracts to vim81/ not vim-8.1/
# -----------------------------------------------------------------------------
build_vim() {
  local tarball
  tarball=$(find_tarball "vim")
  
  if [[ -z "$tarball" || ! -f "$tarball" ]]; then
    echo "❌ vim tarball not found in $BLFS_SOURCES"
    return 1
  fi
  
  echo "Building vim ..."
  
  cd "$BLFS_SOURCES"
  # vim extracts to vim81/ or similar
  rm -rf vim[0-9]*
  tar -xf "$tarball"
  cd vim[0-9]*
  
  echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
  
  ./configure --prefix=/usr
  
  make $MAKEFLAGS
  make install
  
  # Symlinks
  ln -sfv vim /usr/bin/vi 2>/dev/null || true
  
  cd "$BLFS_SOURCES"
  rm -rf vim[0-9]*
  
  echo "Installed: $(vim --version | head -n1)"
}

# =============================================================================
# Main execution
# =============================================================================

# Check sources directory exists
if [[ ! -d "$BLFS_SOURCES" ]]; then
  echo "❌ BLFS sources directory not found: $BLFS_SOURCES"
  echo "   Run init_blfs.sh on host first."
  exit 1
fi

echo ""
echo "Packages to build: ${BLFS_PACKAGES[*]}"
echo "Sources directory: $BLFS_SOURCES"
echo ""

# Verify required tarballs exist
echo "Checking sources..."
missing=0
for pkg in "${BLFS_PACKAGES[@]}"; do
  tarball=$(find_tarball "$pkg")
  if [[ -z "$tarball" || ! -f "$tarball" ]]; then
    echo "  ❌ $pkg (not found)"
    missing=1
  else
    echo "  ✓ $pkg ($(basename "$tarball"))"
  fi
done

if [[ $missing -eq 1 ]]; then
  echo ""
  echo "❌ Missing source packages!"
  echo "   Add URLs to config/blfs-wget-list.txt and run init_blfs.sh"
  exit 1
fi
echo ""

# Build each package
for pkg in "${BLFS_PACKAGES[@]}"; do
  run_step "build_$pkg" "build_$pkg"
done

echo ""
echo "==========================================="
echo "✅ BLFS build complete!"
echo "==========================================="
