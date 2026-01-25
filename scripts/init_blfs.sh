#!/bin/bash
# =============================================================================
# scripts/init_blfs.sh
# 
# RUN ON: Host (before chroot)
# PURPOSE: Download BLFS source packages to $LFS/sources/blfs/
#
# Based on init_lfs.sh style - uses wget-list file for package URLs
# =============================================================================
set -e

#---------------------------------------
# Variables
#---------------------------------------
WGET_LIST_SRC="$BASEDIR/config/blfs-wget-list.txt"
BLFS_SOURCES="$LFS/sources/blfs"
WGET_LIST_DEST="$BLFS_SOURCES/blfs-wget-list.txt"

#---------------------------------------
# Validate environment
#---------------------------------------
if [[ -z "$LFS" ]]; then
  echo "❌ LFS variable is not set."
  exit 1
fi

if [[ -z "$BASEDIR" ]]; then
  echo "❌ BASEDIR variable is not set."
  exit 1
fi

if [[ ! -f "$WGET_LIST_SRC" ]]; then
  echo "❌ Source file $WGET_LIST_SRC does not exist."
  exit 1
fi

#---------------------------------------
# Setup BLFS sources directory
#---------------------------------------
echo "🔧 Setting up BLFS sources directory at: $BLFS_SOURCES ..."
mkdir -pv "$BLFS_SOURCES"
chmod -v a+wt "$BLFS_SOURCES"

#---------------------------------------
# Copy wget-list to BLFS sources
#---------------------------------------
echo "📄 Copying blfs-wget-list to $WGET_LIST_DEST ..."
install -m 644 "$WGET_LIST_SRC" "$WGET_LIST_DEST"

#---------------------------------------
# Download BLFS packages
#---------------------------------------
echo "⬇️  Downloading BLFS source packages ..."
echo "   (skipping existing files, abort on first failure)"
echo ""

count=0
skipped=0

while IFS= read -r url; do
  # Skip empty lines and comments
  [[ -z "$url" || "$url" =~ ^[[:space:]]*# ]] && continue

  # Extract filename (strip query string if any)
  fname="$(basename "${url%%\?*}")"
  dest="$BLFS_SOURCES/$fname"

  # Skip if file already exists and has content
  if [[ -s "$dest" ]]; then
    echo "   ⏭️  (skip) $fname"
    ((skipped++)) || true
    continue
  fi

  echo "   📥 $fname"
  echo "      $url"
  
  wget --timestamping \
       --no-hsts \
       --no-adjust-extension \
       --retry-connrefused \
       --timeout=30 \
       --tries=5 \
       --no-check-certificate \
       --directory-prefix="$BLFS_SOURCES" \
       "$url" || { echo "❌ Download failed: $url"; exit 1; }
  
  ((count++)) || true

done < "$WGET_LIST_DEST"

#---------------------------------------
# Summary
#---------------------------------------
echo ""
echo "==========================================="
echo "✅ BLFS sources ready"
echo "==========================================="
echo "   Directory: $BLFS_SOURCES"
echo "   Downloaded: $count"
echo "   Skipped: $skipped"
echo ""
ls -la "$BLFS_SOURCES"
