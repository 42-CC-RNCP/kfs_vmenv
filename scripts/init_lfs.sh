#!/bin/bash
set -e

# CONFIGURATION
WGET_LIST_SRC="$BASEDIR/config/lfs-wget-list-test.txt"
WGET_LIST_DEST="$LFS/sources/wget-list.txt"

export LFS

echo "🔧 Setting up LFS root structure at: $LFS..."
sudo mkdir -pv $LFS/{sources,tools,md5sums}
sudo chmod -v a+wt $LFS/sources
sudo chown -vR root:root $LFS

# Ensure tools dir exists (redundant safety check)
if [ ! -d "$LFS/tools" ]; then
  sudo mkdir -pv $LFS/tools
fi

# Copy wget-list
if [ ! -f "$WGET_LIST_SRC" ]; then
  echo "❌ Source file $WGET_LIST_SRC does not exist."
  exit 1
fi
if [ ! -d "$(dirname "$WGET_LIST_DEST")" ]; then
  echo "❌ Destination directory $(dirname "$WGET_LIST_DEST") does not exist."
  exit 1
fi

echo "📄 Copying wget-list from $WGET_LIST_SRC to $WGET_LIST_DEST..."
cp -v "$WGET_LIST_SRC" "$WGET_LIST_DEST"

echo "⬇️ Downloading LFS toolchain..."
wget --input-file="$WGET_LIST_DEST" --continue -P "$LFS/sources"
echo "✅ LFS toolchain downloaded."

# Create lfs user and group
echo "👤 Creating LFS user and setting permissions..."
if id -u lfs &>/dev/null; then
  echo "✅ LFS user already exists."
else
  sudo groupadd lfs
  sudo useradd -s /bin/bash -g lfs -m -k /dev/null lfs
fi

# Set correct ownership
sudo chown -Rv lfs:lfs $LFS
sudo chmod -v a+wt $LFS/{sources,tools}

# Configure .bash_profile and .bashrc for lfs user
echo "📝 Configuring LFS user's shell environment..."
sudo -u lfs bash -c "cat > ~/.bash_profile << 'EOF'
exec env -i HOME=\$HOME TERM=\$TERM PS1='\\u:\\w\\$ ' /bin/bash
EOF"

sudo -u lfs bash -c "cat > ~/.bashrc << 'EOF'
set +h
umask 022
LFS=$ROOT_MNT
LC_ALL=POSIX
LFS_TGT=\$(uname -m)-lfs-linux-gnu
PATH=/tools/bin:/bin:/usr/bin
export LFS LC_ALL LFS_TGT PATH
EOF"

echo "✅ Environment configured."
echo
echo "🎉 You can now switch to the LFS user using: 'su - lfs'"
echo "Then continue with the LFS build steps as user 'lfs'."
