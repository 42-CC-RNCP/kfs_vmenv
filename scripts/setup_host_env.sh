#!/bin/bash
# install build tools and dependencies for building the kernel (cross-arch support)

set -e

echo "🔍 Detecting system architecture..."
ARCH=$(uname -m)
echo "🧠 Detected architecture: $ARCH"

echo "🔍 Updating package list..."
sudo apt update

echo "📦 Installing common build tools and dependencies..."
sudo apt install -y \
  build-essential \
  libncurses-dev \
  parted \
  xz-utils zlib1g-dev \
  wget curl m4 git \
  gcc make \
  libssl-dev bc flex bison

if [[ "$ARCH" == "x86_64" ]]; then
  echo "🛠️ Installing x86_64-specific packages..."
  sudo apt install -y \
    grub-pc-bin grub-common \
    qemu-system-x86 qemu-utils
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
  echo "🛠️ Installing arm64-specific packages..."
  sudo apt install -y \
    grub-efi-arm64-bin \
    qemu-system-aarch64 qemu-efi \
    gcc-aarch64-linux-gnu
else
  echo "❌ Unsupported architecture: $ARCH"
  exit 1
fi

echo "🔧 Setting up the Unitial environment..."
wget -O- https://github.com/PeterDaveHello/Unitial/raw/master/setup.sh | bash
export PATH=$PATH:/sbin:/usr/sbin

echo "✅ Host environment setup completed!"
