#!/bin/bash
# scripts/init_lfs.sh
set -e

#---------------------------------------
# Variables
#---------------------------------------
WGET_LIST_SRC="$BASEDIR/config/lfs-wget-list-4.20.12.txt"
WGET_LIST_DEST="$LFS/sources/wget-list.txt"

#---------------------------------------
# Build LFS root structure
#---------------------------------------
echo "🔧 Setting up LFS root structure at: $LFS ..."
sudo mkdir -pv "$LFS"/{sources,tools}
sudo chmod -v a+wt "$LFS/sources"

#---------------------------------------
# Create LFS user and group (book ch4.3)
#---------------------------------------
if id -u lfs &>/dev/null; then
  echo "👤 LFS user already exists."
else
  echo "👤 Creating LFS user and group ..."
  sudo groupadd lfs
  sudo useradd -s /bin/bash -g lfs -m -k /dev/null lfs
fi

#---------------------------------------
# Create /tools symlink (book ch4.2)
#---------------------------------------
echo "🔗 Creating symlink /tools -> $LFS/tools"
sudo mkdir -pv "$LFS/tools"

# If /tools exists and isn't a symlink, stop (avoid accidental overwrite)
if [[ -e /tools && ! -L /tools ]]; then
  echo "❌ /tools exists but is not a symlink. Please remove/rename it first."
  ls -ld /tools
  exit 1
fi

sudo ln -snfv "$LFS/tools" /tools

# Ownership per book: lfs must own tools (and usually sources for downloads/build work)
sudo chown -v lfs:lfs "$LFS/tools"
sudo chown -v lfs:lfs "$LFS/sources"

#---------------------------------------
# Copy wget-list to LFS sources (book ch3)
#---------------------------------------
if [[ ! -f "$WGET_LIST_SRC" ]]; then
  echo "❌ Source file $WGET_LIST_SRC does not exist."
  exit 1
fi

echo "📄 Copying wget-list to $WGET_LIST_DEST ..."
sudo install -m 644 -o root -g root "$WGET_LIST_SRC" "$WGET_LIST_DEST"

echo "⬇️  Downloading LFS toolchain sources (abort on first failure) ..."
while IFS= read -r url; do
  [[ -z "$url" || "$url" =~ ^[[:space:]]*# ]] && continue

  echo "   -> $url"
  wget --timestamping \
       --no-hsts \
       --no-adjust-extension \
       --retry-connrefused --timeout=30 \
       --tries=5 --no-check-certificate \
       --directory-prefix="$LFS/sources" \
       "$url" || { echo "❌ Download failed: $url"; exit 1; }

done < "$WGET_LIST_DEST"

echo "✅ Sources downloaded (only new files were fetched)."

#---------------------------------------
# Configure LFS user's environment (book ch4.4)
#---------------------------------------
echo "📝 Configuring LFS user's shell environment ..."

sudo -u lfs bash -c "cat > ~/.bash_profile <<'EOF'
# LFS environment setup
exec env -i HOME=\$HOME TERM=\$TERM PS1='(lfs) \\u:\\w\\$ ' /bin/bash
EOF"

sudo -u lfs bash -c "cat > ~/.bashrc <<'EOF'
set +h
umask 022
LFS=$(readlink -f "$LFS")
LC_ALL=POSIX
LFS_TGT=\$(uname -m)-lfs-linux-gnu
PATH=/tools/bin:/bin:/usr/bin
export LFS LC_ALL LFS_TGT PATH
EOF"

sudo mkdir -p "$LFS/sources/.kfs" "$LFS/tools"
sudo chown -v lfs:lfs "$LFS/sources/.kfs" "$LFS/tools"

echo "✅ LFS environment is ready."
echo
echo "👉  Switch to the LFS user with:  sudo su - lfs"
echo "🔰  Then continue building the toolchain as the 'lfs' user."
