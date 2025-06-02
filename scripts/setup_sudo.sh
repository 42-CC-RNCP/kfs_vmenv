#!/bin/bash
# This script checks if the current user is in the 'sudo' group.
# If not, it adds the user to the group and prompts for reboot.

set -e

USERNAME="$(whoami)"

# Check if the user is already in the sudo group
if groups "$USERNAME" | grep -q '\bsudo\b'; then
    echo "✅ User '$USERNAME' is already in the sudo group."
else
    echo "➕ Adding user '$USERNAME' to the sudo group..."
    sudo usermod -aG sudo "$USERNAME"

    echo ""
    echo "🔐 The sudo group change is saved, but it won't take effect immediately."
    echo "📌 You must either:"
    echo "   1. Log out and log back in"
    echo "   2. Run: newgrp sudo"
    echo "   3. Reboot the system"

    echo ""
    read -rp "Do you want to reboot now to apply the change? (Y/n) " answer
    if [[ "$answer" =~ ^[Yy]$ || -z "$answer" ]]; then
        echo "🔄 Rebooting the system..."
        sudo reboot
    else
        echo "🕒 Please manually log out or run 'newgrp sudo' later."
    fi
fi
