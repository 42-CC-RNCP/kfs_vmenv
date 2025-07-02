#!/bin/bash
set -e

#---------------------------------------
# Variables
#---------------------------------------
WGET_LIST_SRC="$BASEDIR/config/lfs-wget-list-minimal.txt"
WGET_LIST_DEST="$LFS/sources/wget-list.txt"

#---------------------------------------
# Build LFS root structure
#---------------------------------------
echo "🔧 Setting up LFS root structure at: $LFS ..."
sudo mkdir -pv $LFS/{sources,tools,md5sums}
sudo chmod -v a+wt $LFS/sources
sudo chown -vR root:root "$LFS"

#---------------------------------------
# Create symlink /tools
#---------------------------------------
if [[ ! -L /tools ]]; then
  echo "🔗 Creating symlink /tools -> $LFS/tools"
  sudo ln -sv "$LFS/tools" /
else
  echo "✅ Symlink /tools already exists → $(readlink -f /tools)"
fi

#---------------------------------------
# Check if LFS exists
#---------------------------------------
sudo mkdir -pv "$LFS/tools"

#---------------------------------------
# Copy wget-list to LFS sources
#---------------------------------------
if [[ ! -f "$WGET_LIST_SRC" ]]; then
  echo "❌ Source file $WGET_LIST_SRC does not exist."
  exit 1
fi

echo "📄 Copying wget-list to $WGET_LIST_DEST ..."
sudo install -m 644 -o root -g root "$WGET_LIST_SRC" "$WGET_LIST_DEST"

echo "⬇️  Downloading LFS toolchain sources ..."
wget --input-file="$WGET_LIST_DEST" \
     --continue --timestamping \
     --retry-connrefused --timeout=30 \
      --tries=5 --no-check-certificate \
     --directory-prefix="$LFS/sources"
echo "✅ Sources downloaded (only new or unfinished files were fetched)."

#---------------------------------------
# Create LFS user and group
#---------------------------------------
if id -u lfs &>/dev/null; then
  echo "👤 LFS user already exists."
else
  echo "👤 Creating LFS user and group ..."
  sudo groupadd lfs
  sudo useradd -s /bin/bash -g lfs -m -k /dev/null lfs
fi

# Change ownership and permissions
sudo chown -Rv lfs:lfs "$LFS"
sudo chmod -v a+wt "$LFS"/{sources,tools}

#---------------------------------------
# Configure LFS user's environment
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
PATH=/tools/bin:/usr/bin:/bin
export LFS LC_ALL LFS_TGT PATH
EOF"

echo "✅ LFS environment is ready."
echo
echo "👉  Switch to the LFS user with:  sudo su - lfs"
echo "🔰  Then continue building the toolchain as the 'lfs' user."
