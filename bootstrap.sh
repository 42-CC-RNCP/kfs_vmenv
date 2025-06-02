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

echo -e "${BLUE}🚀 Starting full ft_linux setup...${NC}"

run_step "Clean existing loop and mounts" "./scripts/cleanup.sh"
run_step "Create disk and partition"    "./scripts/create_disk.sh"
run_step "Install root filesystem"      "./scripts/install_rootfs.sh"
run_step "Build and install kernel"     "./scripts/build_kernel.sh"
run_step "Set up bootloader"            "./scripts/setup_bootloader.sh"

echo -e "${GREEN}🎉 All steps completed successfully! You can now boot into your ft_linux system.${NC}"
