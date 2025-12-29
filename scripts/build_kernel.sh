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

KERNEL_TARBALL="/tmp/${KERNEL_NAME}.tar.xz"
BOOT_DIR="${BOOT_MNT}"

echo "📦 Downloading kernel ${KERNEL_VERSION}..."
mkdir -p /tmp
cd /tmp
wget -c -O "$KERNEL_TARBALL" "$KERNEL_URL"

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
  make defconfig
fi

echo "⚙️  Building kernel (bzImage + modules)..."
make -j"$(nproc)"

echo "📦 Installing modules into LFS rootfs..."
make modules_install INSTALL_MOD_PATH="$LFS"

echo "📁 Installing kernel files into LFS /boot..."
mkdir -pv "$BOOT_DIR"

cp -iv arch/x86/boot/bzImage "$BOOT_DIR/vmlinuz-${KERNEL_VERSION}-${HOST}"

cp -iv System.map "$BOOT_DIR/System.map-${KERNEL_VERSION}"
cp -iv .config    "$BOOT_DIR/config-${KERNEL_VERSION}"

# echo "📄 (Optional) Installing kernel docs into LFS..."
# install -dv "${LFS}/usr/share/doc/linux-${KERNEL_VERSION}"
# cp -r Documentation/* "${LFS}/usr/share/doc/linux-${KERNEL_VERSION}/"

echo "📄 Copying kernel tarball into LFS sources..."
mkdir -p "${LFS}/sources"
cp -v "$KERNEL_TARBALL" "${LFS}/sources/"

echo "✅ Kernel build & install completed."
echo "   - Kernel:  ${BOOT_DIR}/vmlinuz-${KERNEL_VERSION}-${HOST}"
echo "   - Map:     ${BOOT_DIR}/System.map-${KERNEL_VERSION}"
echo "   - Config:  ${BOOT_DIR}/config-${KERNEL_VERSION}"
echo "   - Modules: ${LFS}/lib/modules/"
