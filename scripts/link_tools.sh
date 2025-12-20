#!/bin/bash
set -euo pipefail

: "${LFS:?❌ LFS not set}"

echo "🔗 Ensuring /tools -> $LFS/tools"

mkdir -pv "$LFS/tools"

if [[ -e /tools && ! -L /tools ]]; then
  echo "❌ /tools exists but is not a symlink. Please remove/rename it first."
  ls -ld /tools
  exit 1
fi

target="$(readlink -f "$LFS/tools")"

if [[ -L /tools ]]; then
  cur="$(readlink -f /tools)"
  if [[ "$cur" != "$target" ]]; then
    echo "⚠️  /tools currently points to: $cur"
    echo "🔧 Fixing /tools -> $target"
    ln -snfv "$target" /tools
  else
    echo "✅ /tools already correct: $cur"
  fi
else
  ln -snfv "$target" /tools
fi

hash -r || true
echo "✅ /tools ready."
