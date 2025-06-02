#!/bin/bash
set -e

BOOTDIR=${BOOT_MNT}

echo "🧩 Detecting loop device..."
LOOPDEV=$(losetup -j "$IMAGE" | cut -d: -f1)
if [[ -z "$LOOPDEV" ]]; then
  echo "❌ ERROR: loop device not found. Make sure kernel_disk.img is attached."
  exit 1
fi

echo "🪛 Installing GRUB to $LOOPDEV..."
sudo grub-install \
  --target=i386-pc \
  --boot-directory="$BOOTDIR" \
  "$LOOPDEV"

echo "📝 Createing grub.cfg..."
sudo mkdir -p "$BOOTDIR/grub"
cat <<EOF | sudo tee "$BOOTDIR/grub/grub.cfg" > /dev/null
set timeout=5
set default=0

menuentry 'ft_linux' {
    linux /boot/vmlinuz-${KERNEL_VERSION}-${HOST} root=LABEL=root rw quiet
}
EOF

ls -al "$BOOTDIR/grub/grub.cfg"

echo "✅ GRUB bootloader installed successfully!"
