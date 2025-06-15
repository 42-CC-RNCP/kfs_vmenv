#!/bin/bash
set -e

# Config
INSTALL_DIR=${MNT_ROOT}
ARCH=$(uname -m)

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
case "$ARCH" in
  x86_64)
    KERNEL_IMAGE_PATH="arch/x86/boot/bzImage"
    ;;
  aarch64 | arm64)
    KERNEL_IMAGE_PATH="arch/arm64/boot/Image"
    ;;
  *)
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

cp "$KERNEL_IMAGE_PATH" "$INSTALL_DIR/boot/vmlinuz-${KERNEL_VERSION}-${HOST}"

echo "📦 Installing modules..."
make modules_install INSTALL_MOD_PATH="$INSTALL_DIR"

echo "📚 Installing kernel headers..."
make headers_install INSTALL_HDR_PATH="$BUILD_DIR/dest"
cp -rv "$BUILD_DIR/dest/include/*" "$INSTALL_DIR/usr/include/"

echo "✅ Kernel build and install completed."
