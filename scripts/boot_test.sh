#!/bin/bash
# scripts/boot_test.sh

set -e

IMAGE="${IMAGE:-kernel_disk.img}"
LOG_FILE="boot_debug_$(date +%Y%m%d_%H%M%S).log"

echo "🚀 Debug boot test..."
echo "   All output will be saved to: $LOG_FILE"
echo ""

{
  echo "=== Boot Test Started at $(date) ==="
  echo ""
  
  timeout 60 qemu-system-x86_64 \
    -drive file="$IMAGE",format=raw \
    -m 1G \
    -boot c \
    -nographic \
    -serial mon:stdio \
    -d cpu_reset,guest_errors \
    -D qemu_debug.log
    
} 2>&1 | tee "$LOG_FILE"

echo ""
echo "=== Analysis ==="

if grep -qi "grub" "$LOG_FILE"; then
  echo "✅ Stage 1: GRUB loaded"
else
  echo "❌ Stage 1: GRUB not detected"
fi

if grep -qi "linux version" "$LOG_FILE"; then
  echo "✅ Stage 2: Kernel started"
else
  echo "❌ Stage 2: Kernel not started"
fi

if grep -qi "mount" "$LOG_FILE"; then
  echo "✅ Stage 3: Filesystem mounting"
else
  echo "❌ Stage 3: No filesystem activity"
fi

if grep -qi "init" "$LOG_FILE"; then
  echo "✅ Stage 4: Init process"
else
  echo "❌ Stage 4: Init not started"
fi

if grep -qi "login\|sh-" "$LOG_FILE"; then
  echo "✅ Stage 5: User space reached"
else
  echo "❌ Stage 5: Did not reach user space"
fi

echo ""
echo "📄 Full logs:"
echo "  - Boot output: $LOG_FILE"
echo "  - QEMU debug: qemu_debug.log"
