#!/bin/bash
set -e

# !!should be run in chroot environment

echo "📝 Installing GRUB bootloader..."

grub-install /dev/sda

echo "📝 Creating GRUB configuration..."
cat > /boot/grub/grub.cfg << "EOF"
# Begin /boot/grub/grub.cfg
set default=0
set timeout=5

insmod ext2
set root=(hd0,1)

menuentry "GNU/Linux, Linux 4.20.12-lyeh" {
        linux   /vmlinuz-4.20.12-lyeh root=/dev/sda2 ro
}
EOF

echo "✅ GRUB installation complete!"
