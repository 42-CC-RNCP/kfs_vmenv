#!/bin/bash
set -eEuo pipefail

echo "🔧 ch7.2"

STAMP_DIR="/.kfs/stamps/ch7"
mkdir -p "$STAMP_DIR"

run_step() {
  local name="$1"; shift
  local stamp="$STAMP_DIR/$name.done"
  if [[ -f "$stamp" ]]; then
    echo "✅ (skip) $name"
    return 0
  fi
  echo "🔷 RUN $name"
  "$@"
  touch "$stamp"
  echo "✅ DONE $name"
}

build_bootscripts() {
  echo "📦 Building and installing bootscripts ..."
  cd /sources
  tar -xf lfs-bootscripts-20180820.tar.bz2
  cd lfs-bootscripts-20180820

  make install
  echo "✅ bootscripts installed."
}

run_step "build_bootscripts" build_bootscripts
echo "✅ ch7.2 completed."
