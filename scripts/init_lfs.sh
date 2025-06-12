#!/bin/bash
set -e

export LFS=${ROOT_MNT}

echo -e "Setting up LFS structure in ${LFS}..."
sudo mkdir -pv $LFS/{sources,tools,md5sums}
sudo chmod -v a+wt $LFS/sources
sudo chown -vR root:root $LFS

if [ ! -d "$LFS/tools" ]; then
  sudo mkdir -pv $LFS/tools
fi

# Check if wget-list.html exists, if not, download it
if [ ! -f "$LFS/sources/wget-list.html" ]; then
  echo "⬇️ Downloading LFS toolchain list..."
  wget -N https://www.linuxfromscratch.org/lfs/downloads/stable/wget-list
  # wget -N https://www.linuxfromscratch.org/lfs/downloads/stable/md5sums

  echo "⬇️ Downloading LFS toolchain..."
  wget --input-file=wget-list.html --continue -P $LFS/sources
  echo "✅ LFS toolchain downloaded."
  # echo "📦 Verifying LFS toolchain integrity..."
  # cd $LFS/sources
  # md5sum -c ../md5sums --ignore-missing
  # echo "✅ LFS toolchain downloaded and verified."
else
  echo "✅ LFS toolchain list already exists."
fi

echo "👤 Create LFS user and group only for cross-platform toolchain"
sudo groupadd lfs
id -u lfs &>/dev/null || sudo useradd -s /bin/bash -g lfs -m -k /dev/null lfs
sudo chown -v lfs $LFS/{,sources,tools}
sudo chmod -v a+wt $LFS/{,sources,tools}

echo "🔧 Setting up LFS environment variables..."
sudo -u lfs bash -c 'cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1="\\u:\\w\\$ " /bin/bash
EOF'

sudo -u lfs bash -c 'cat > ~/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/kernel_disk/root
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/tools/bin:/bin:/usr/bin
export LFS LC_ALL LFS_TGT PATH
EOF'

echo "✅ LFS environment variables set up."
echo
echo "You can now switch to the LFS user with 'su - lfs' to continue the LFS build process."
