#!/bin/bash
# scripts/install_grub_to_img.sh
set -e

# require environment variables from bootstrap.sh
if [[ -f "$ROOT_MNT/.disk_info" ]]; then
    source "$ROOT_MNT/.disk_info"
else
    echo "❌ Could not find disk info file at $ROOT_MNT/.disk_info. Please ensure the environment is set up correctly."
    exit 1
fi

echo "💾 Installing GRUB to image: $IMAGE"
echo "🔍 Target Loop Device: $LOOPDEV"
echo "📂 Boot directory path: $BOOT_MNT"

sudo grub-install --target=i386-pc \
                 --boot-directory="$BOOT_MNT" \
                 "$LOOPDEV"

echo "✅ GRUB installed to $IMAGE successfully."
