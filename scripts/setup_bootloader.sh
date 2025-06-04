#!/bin/bash
set -e

BOOTDIR=${BOOT_MNT}
ARCH=$(uname -m)

echo "🧩 Detecting loop device..."
LOOPDEV=$(losetup -j "$IMAGE" | cut -d: -f1)
if [[ -z "$LOOPDEV" ]]; then
  echo "❌ ERROR: loop device not found. Make sure kernel_disk.img is attached."
  exit 1
fi

echo "🧭 Detected architecture: $ARCH"

case "$ARCH" in
  x86_64)
    GRUB_TARGET="i386-pc"
    ;;
  aarch64 | arm64)
    GRUB_TARGET="arm64-efi"
    ;;
  *)
    echo "❌ ERROR: Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

echo "🪛 Installing GRUB to $LOOPDEV using target $GRUB_TARGET with boot directory: $BOOTDIR"
sudo grub-install \
  --target="$GRUB_TARGET" \
  --boot-directory="$BOOTDIR" \
  --modules="part_gpt part_msdos ext2" \
  "$LOOPDEV"

echo "📝 Creating grub.cfg..."
sudo mkdir -p "$BOOTDIR/grub"
cat <<EOF | sudo tee "$BOOTDIR/grub/grub.cfg" > /dev/null
set timeout=5
set default=0

menuentry 'ft_linux' {
    linux /boot/vmlinuz-${KERNEL_VERSION}-${HOST} root=LABEL=root rw quiet
}
EOF

echo "📄 grub.cfg content:"
ls -al "$BOOTDIR/grub/grub.cfg"
cat "$BOOTDIR/grub/grub.cfg"

echo "✅ GRUB bootloader installed successfully!"
