#!/bin/bash
set -e

echo "🔧 Configuring system..."

echo "lfs" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1 localhost
::1       localhost
127.0.1.1 lfs
EOF

cat > /etc/fstab <<EOF
/dev/sda1 /     ext4    defaults 1 1
EOF

cat > /etc/passwd <<EOF
root:x:0:0:root:/root:/bin/bash
EOF

cat > /etc/group <<EOF
root:x:0:
EOF

echo "root:password" | chpasswd

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "✅ System config done."
