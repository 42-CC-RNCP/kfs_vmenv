#!/bin/bash
set -e

# Config
BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
KERNEL_VERSION="4.19.295"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-${KERNEL_VERSION}.tar.xz"
KERNEL_NAME="linux-${KERNEL_VERSION}"
BUILD_DIR="/tmp/$KERNEL_NAME"
INSTALL_DIR="/mnt/kernel_disk"
LOGIN="lyeh"

echo "📦 Downloading kernel $KERNEL_VERSION..."
mkdir -p /tmp
cd /tmp
wget -c "$KERNEL_URL"
tar -xf "$KERNEL_NAME.tar.xz"

cd "$BUILD_DIR"

echo "🛠️  Configuring kernel..."
cp "$BASEDIR/config/kernel.config" .config
make mrproper

echo "⚙️  Building kernel..."
make -j$(nproc)

echo "📁 Installing kernel image..."
cp arch/x86/boot/bzImage "$INSTALL_DIR/boot/vmlinuz-${KERNEL_VERSION}-${LOGIN}"

echo "📦 Installing modules..."
make modules_install INSTALL_MOD_PATH="$INSTALL_DIR"

echo "✅ Kernel build and install completed."
