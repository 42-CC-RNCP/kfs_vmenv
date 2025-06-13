#!/bin/bash
set -e

# Boot test for LFS image using QEMU

ARCH=$(uname -m)
IMAGE=${IMAGE:-kernel_disk.img}
MEM="1024"  # MB

if [[ ! -f "$IMAGE" ]]; then
  echo "❌ Error: Disk image '$IMAGE' not found."
  exit 1
fi

echo "🖥️  Starting boot test for image: $IMAGE"
echo "🧠  Architecture detected: $ARCH"

case "$ARCH" in
  x86_64)
    echo "🚀 Launching QEMU for x86_64..."
    qemu-system-x86_64 \
      -m "$MEM" \
      -drive file="$IMAGE",format=raw,if=ide \
      -nographic \
      -serial mon:stdio \
      -no-reboot
    ;;
  aarch64 | arm64)
    echo "🚧 UEFI boot on ARM64 is not yet implemented in this script."
    echo "   You may need: -machine virt -cpu cortex-a57 -bios QEMU_EFI.fd ..."
    ;;
  *)
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
    ;;
esac
