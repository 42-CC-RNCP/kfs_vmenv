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
# Export environment variables
# ----------------------------
ARCH=$(uname -m)
HOST="lyeh"
BASEDIR=$(pwd)
KERNEL_VERSION="4.20.12"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-${KERNEL_VERSION}.tar.xz"
KERNEL_NAME="linux-${KERNEL_VERSION}"
BUILD_DIR="/tmp/$KERNEL_NAME"
IMAGE="kernel_disk.img"
IMAGE_SIZE="20G"
MNT_ROOT="/mnt/kernel_disk"
BOOT_MNT="$MNT_ROOT/boot"
ROOT_MNT="$MNT_ROOT/root"
BUSYBOX_URL="https://busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-x86_64"
LFS="/mnt/lfs"
LFS_TGT="$(uname -m)-lfs-linux-gnu"

export HOST BASEDIR KERNEL_VERSION KERNEL_URL KERNEL_NAME BUILD_DIR \
       IMAGE IMAGE_SIZE MNT_ROOT BOOT_MNT ROOT_MNT BUSYBOX_URL LFS LFS_TGT

echo -e "${GREEN}🌟 Environment variables set:${NC}"
env | grep -E '^(ARCH|HOST|BASEDIR|KERNEL_VERSION|KERNEL_URL|KERNEL_NAME|BUILD_DIR|IMAGE|IMAGE_SIZE|MNT_ROOT|BOOT_MNT|ROOT_MNT|BUSYBOX_URL|LFS|LFS_TGT)='

# ----------------------------
# Define steps and their scripts
# ----------------------------
declare -A STEPS=(
  [cleanup]="WIPE_LFS_TOOLS=1 ./scripts/cleanup.sh"
  [create_disk]="./scripts/create_disk.sh"
  [install_rootfs]="./scripts/install_rootfs.sh"
  [build_kernel]="./scripts/build_kernel.sh"
  [setup_bootloader]="./scripts/setup_bootloader.sh"
  [init_lfs]="./scripts/init_lfs.sh"
  [link_tools]="./scripts/link_tools.sh"
  [build_temp_toolchain]="sudo -u lfs env -i HOME=/home/lfs TERM=\"$TERM\" \
    LFS=\"$LFS\" LFS_TGT=\"$LFS_TGT\" BASEDIR=\"$BASEDIR\" BUILD_DIR=\"$BUILD_DIR\" \
    PATH=\"/tools/bin:/usr/bin:/bin\" \
    /bin/bash ./scripts/build_temp_toolchain.sh"
  [finalize_tools_owner]="chown -R root:root \"$LFS/tools\""
  [mount_lfs]="./scripts/mount_lfs.sh"
  [build_lfs_toolchain]="chroot_exec ./scripts/build_lfs_toolchain.sh"
  [config_system]="chroot_exec config_system.sh"
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
  link_tools
  build_temp_toolchain
  finalize_tools_owner
  mount_lfs
  build_lfs_toolchain
  # config_system
  # unmount_lfs
  # boot_test
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
    local inside_path="/scripts/$(basename "$inside_script")"

    chroot "$LFS" /tools/bin/env -i \
        HOME=/root                  \
        TERM="$TERM"                \
        PS1='(lfs chroot) \u:\w\$ ' \
        PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
        /tools/bin/bash --login +h "$inside_path"
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
FROM_STEP=""

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
    --from)
      MODE="from"
      FROM_STEP=$2
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
  from)
    if [[ -z "$FROM_STEP" ]]; then
      echo -e "${RED}❌ Please provide a step name after --from${NC}"
      exit 1
    fi
    found=false
    for step in "${STEP_ORDER[@]}"; do
      if [[ "$step" == "$FROM_STEP" ]]; then
        found=true
      fi
      if $found; then
        run_step "$step"
      fi
    done
    if ! $found; then
      echo -e "${RED}❌ Step '$FROM_STEP' not found in STEP_ORDER${NC}"
      exit 1
    fi
    ;;
  *)
    echo -e "${BLUE}Usage:${NC}"
    echo "  $0 --auto                Run all steps"
    echo "  $0 --step <step_name>    Run only a specific step"
    echo "  $0 --from <step_name>    Run all steps starting from the specified one"
    echo
    echo -e "${BLUE}Available steps:${NC} ${STEP_ORDER[*]}"
    exit 0
    ;;
esac
