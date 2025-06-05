#!/bin/bash
set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
run_step() {
  local name=$1
  local script=$2

  echo -e "${BLUE}🔷 [Step] $name...${NC}"
  if [[ ! -x "$script" ]]; then
    echo -e "${RED}❌ Error: script '$script' not found or not executable.${NC}"
    exit 1
  fi

  if "$script"; then
    echo -e "${GREEN}✅ $name completed.${NC}"
  else
    echo -e "${RED}❌ $name failed! Stopping.${NC}"
    exit 1
  fi
}

# Check if running with sudo
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}❗ This script must be run as root or with sudo.${NC}"
  exit 1
fi

echo -e "${BLUE} Export environment variables...${NC}"

ARCH=$(uname -m)
HOST="lyeh"
BASEDIR=$(pwd)
KERNEL_VERSION="4.19.295"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-${KERNEL_VERSION}.tar.xz"
KERNEL_NAME="linux-${KERNEL_VERSION}"
BUILD_DIR="/tmp/$KERNEL_NAME"

IMAGE="kernel_disk.img"
IMAGE_SIZE="10G"
MNT_ROOT="/mnt/kernel_disk"
BOOT_MNT="$MNT_ROOT/boot"
ROOT_MNT="$MNT_ROOT/root"
BUSYBOX_URL="https://busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-x86_64"

export HOST BASEDIR KERNEL_VERSION KERNEL_URL KERNEL_NAME BUILD_DIR INSTALL_DIR \
       IMAGE IMAGE_SIZE MNT_ROOT BOOT_MNT ROOT_MNT BUSYBOX_URL

echo -e "${GREEN}🌟 Environment variables set:${NC}"
env | grep -E '^(HOST|BASEDIR|KERNEL_VERSION|KERNEL_URL|KERNEL_NAME|BUILD_DIR|INSTALL_DIR|IMAGE|SIZE|MNT_ROOT|BOOT_MNT|ROOT_MNT|BUSYBOX_URL)='

echo -e "${BLUE}🚀 Starting full ft_linux setup...${NC}"

run_step "Clean existing loop and mounts" "./scripts/cleanup.sh"
run_step "Create disk and partition"    "./scripts/create_disk.sh"
run_step "Install root filesystem"      "./scripts/install_rootfs.sh"
run_step "Build and install kernel"     "./scripts/build_kernel.sh"
run_step "Set up bootloader"            "./scripts/setup_bootloader.sh"
run_step "Install tools"                "./scripts/install_tool.sh"

echo -e "${GREEN}🎉 All steps completed successfully! You can now boot into your ft_linux system.${NC}"

echo -e "${BLUE}Simulating boot process for detected architecture: ${ARCH}${NC}"

if [[ "$ARCH" == "x86_64" ]]; then
  echo -e "${BLUE}BIOS boot with qemu-system-x86_64:${NC}"
  echo "sudo qemu-system-x86_64 -drive file=$IMAGE,format=raw,if=ide"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
  echo -e "${BLUE}UEFI boot with qemu-system-aarch64:${NC}"
  echo "TBD"
else
  echo "❌ Unsupported architecture: $ARCH"
fi
