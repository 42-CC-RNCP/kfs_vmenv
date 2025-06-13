#!/bin/bash
set -e

# ----------------------------
# Color codes
# ----------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# ----------------------------
# Define steps and their scripts
# ----------------------------
declare -A STEPS=(
  [cleanup]="./scripts/cleanup.sh"
  [create_disk]="./scripts/create_disk.sh"
  [install_rootfs]="./scripts/install_rootfs.sh"
  [build_kernel]="./scripts/build_kernel.sh"
  [setup_bootloader]="./scripts/setup_bootloader.sh"
  [init_lfs]="./scripts/init_lfs.sh"
  [build_toolchain]="sudo -u lfs bash /mnt/kernel_disk/root/sources/build_lfs_core.sh"
  [mount_lfs]="./scripts/mount_lfs.sh"
  [build_lfs_system]="chroot_exec ./scripts/build_lfs_system.sh"
  [config_system]="chroot_exec ./scripts/config_system.sh"
  [unmount_lfs]="./scripts/unmount_lfs.sh"
  [boot_test]="./scripts/boot_test.sh"
)

STEP_ORDER=(
  cleanup
  create_disk
  install_rootfs
  build_kernel
  setup_bootloader
  init_lfs
  build_toolchain
  mount_lfs
  build_lfs_system
  config_system
  unmount_lfs
  boot_test
)

# ----------------------------
# Function: run a named step
# ----------------------------
run_step() {
  local name=$1
  local cmd="${STEPS[$name]}"

  echo -e "${BLUE}🔷 Running step: $name${NC}"

  if [[ "$cmd" == chroot_exec* ]]; then
    local inside_script="${cmd#chroot_exec }"
    chroot "$LFS" /tools/bin/env -i \
      HOME=/root TERM="$TERM" PS1='(lfs) \u:\w\$ ' \
      PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
      /tools/bin/bash --login -c "$inside_script"
  else
    if ! eval "$cmd"; then
      echo -e "${RED}❌ Step '$name' failed. Aborting.${NC}"
      exit 1
    fi
  fi

  echo -e "${GREEN}✅ Step '$name' completed.${NC}"
}

# ----------------------------
# Parse command line arguments
# ----------------------------
MODE=""
TARGET_STEP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto)
      MODE="auto"
      shift
      ;;
    --step)
      MODE="step"
      TARGET_STEP=$2
      shift 2
      ;;
    *)
      echo -e "${RED}❌ Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

# ----------------------------
# Check root privilege
# ----------------------------
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}❗ This script must be run as root.${NC}"
  exit 1
fi

# ----------------------------
# Export environment variables
# ----------------------------
ARCH=$(uname -m)
HOST="lyeh"
BASEDIR=$(pwd)
KERNEL_VERSION="4.19.295"
KERNEL_NAME="linux-${KERNEL_VERSION}"
BUILD_DIR="/tmp/$KERNEL_NAME"
IMAGE="kernel_disk.img"
IMAGE_SIZE="10G"
MNT_ROOT="/mnt/kernel_disk"
BOOT_MNT="$MNT_ROOT/boot"
ROOT_MNT="$MNT_ROOT/root"
BUSYBOX_URL="https://busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-x86_64"
LFS="$ROOT_MNT"

export HOST BASEDIR KERNEL_VERSION KERNEL_NAME BUILD_DIR IMAGE IMAGE_SIZE \
       MNT_ROOT BOOT_MNT ROOT_MNT BUSYBOX_URL LFS

echo -e "${GREEN}🌟 Environment variables set:${NC}"
env | grep -E '^(LFS|IMAGE|KERNEL_VERSION|HOST|MNT_ROOT|ROOT_MNT|BOOT_MNT)='

# ----------------------------
# Run steps based on mode
# ----------------------------
case "$MODE" in
  auto)
    for step in "${STEP_ORDER[@]}"; do
      run_step "$step"
    done
    ;;
  step)
    if [[ -z "$TARGET_STEP" ]]; then
      echo -e "${RED}❌ Please provide a step name after --step${NC}"
      exit 1
    fi
    run_step "$TARGET_STEP"
    ;;
  *)
    echo -e "${BLUE}Usage:${NC}"
    echo "  $0 --auto                Run all steps"
    echo "  $0 --step <step_name>    Run only a specific step"
    echo
    echo -e "${BLUE}Available steps:${NC} ${STEP_ORDER[*]}"
    exit 0
    ;;
esac
