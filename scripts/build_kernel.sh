#!/bin/bash
set -euo pipefail

ARCH="$(uname -m)"
if [[ "$ARCH" != "x86_64" ]]; then
  echo "❌ This script is for x86_64 only. Current: $ARCH"
  exit 1
fi

: "${BASEDIR:?BASEDIR is not set}"
: "${KERNEL_VERSION:?KERNEL_VERSION is not set}"
: "${KERNEL_URL:?KERNEL_URL is not set}"
: "${KERNEL_NAME:?KERNEL_NAME is not set}"
: "${BUILD_DIR:?BUILD_DIR is not set}"
: "${LFS:?LFS is not set}"
: "${HOST:?HOST is not set}"
: "${BOOT_MNT:?BOOT_MNT is not set}"

cd /sources

KERNEL_TARBALL="${KERNEL_NAME}.tar.xz"
BOOT_DIR="${BOOT_MNT}"

if [[ ! -f "$KERNEL_TARBALL" ]]; then
  echo "📦 Downloading kernel ${KERNEL_VERSION}..."
  wget -c "${KERNEL_URL}/${KERNEL_TARBALL}"
fi

echo "🧹 Preparing kernel source tree..."
rm -rf "$BUILD_DIR"
tar -xf "$KERNEL_TARBALL"
cd "$BUILD_DIR"

make mrproper

echo "🛠️  Configuring kernel..."
if [[ -f "$BASEDIR/config/kernel.config" ]]; then
  cp -v "$BASEDIR/config/kernel.config" .config
  make olddefconfig
else
  echo "❗ No kernel config found at $BASEDIR/config/kernel.config"
  echo "   Please provide a valid kernel config file."
  exit 1
fi

echo "⚙️  Building kernel (bzImage + modules)..."
make -j"$(nproc)"

echo "📦 Installing modules..."
make modules_install

echo "📁 Installing kernel files to /boot..."
cp -iv arch/x86/boot/bzImage "/boot/vmlinuz-${KERNEL_VERSION}-${LFS_VERSION}"
cp -iv System.map "/boot/System.map-${KERNEL_VERSION}"
cp -iv .config "/boot/config-${KERNEL_VERSION}"

echo "📄 Installing kernel documentation..."
install -d "/usr/share/doc/linux-${KERNEL_VERSION}"
cp -r Documentation/* "/usr/share/doc/linux-${KERNEL_VERSION}/"

echo "🔒 Setting ownership of kernel source tree..."
cd /sources
chown -R 0:0 "$KERNEL_NAME"

echo "✅ Kernel build completed successfully!"
echo ""
echo "Installed files:"
echo "  - Kernel: /boot/vmlinuz-${KERNEL_VERSION}-${LFS_VERSION}"
echo "  - Map:    /boot/System.map-${KERNEL_VERSION}"
echo "  - Config: /boot/config-${KERNEL_VERSION}"
echo "  - Modules: /lib/modules/${KERNEL_VERSION}"
echo ""
echo "Next step: Install GRUB bootloader"
