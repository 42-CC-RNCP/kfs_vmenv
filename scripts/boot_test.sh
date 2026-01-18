#!/bin/bash
# test_boot.sh

IMAGE="kernel_disk.img"

echo "🚀 Testing boot with QEMU..."

qemu-system-x86_64 \
  -drive file="$IMAGE",format=raw \
  -m 1G \
  -boot c \
  -serial stdio \
  -display none

qemu-system-x86_64 \
  -drive file="$IMAGE",format=raw \
  -m 1G \
  -boot c
