#!/bin/bash
set -e

# Config
INSTALL_DIR=${MNT_ROOT}

echo "📦 Downloading kernel $KERNEL_VERSION..."
mkdir -p /tmp
cd /tmp
wget -c "$KERNEL_URL"
tar -xf "$KERNEL_NAME.tar.xz"

cd "$BUILD_DIR"

echo "🛠️  Configuring kernel..."
cp "$BASEDIR/config/kernel.config" .config
make olddefconfig

echo "⚙️  Building kernel..."
make -j$(nproc)

echo "📁 Installing kernel image..."
cp arch/x86/boot/bzImage "$INSTALL_DIR/boot/vmlinuz-${KERNEL_VERSION}-${HOST}"

echo "📦 Installing modules..."
make modules_install INSTALL_MOD_PATH="$INSTALL_DIR"

echo "✅ Kernel build and install completed."
