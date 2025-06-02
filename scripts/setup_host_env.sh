#!/bin/bash
# install build tools and dependencies for building the kernel

set -e

echo "🔍 Updating package list..."
sudo apt update

echo "📦 Installing build tools and dependencies..."
sudo apt install -y \
  build-essential \
  libncurses-dev \
  grub-pc-bin grub-common \
  parted \
  xz-utils zlib1g-dev \
  wget curl m4 git

echo "🔧 Setting up the Unitial environment..."
wget  -O- https://github.com/PeterDaveHello/Unitial/raw/master/setup.sh | bash
export PATH=$PATH:/sbin:/usr/sbin
echo "✅ Host environment setup completed!"
