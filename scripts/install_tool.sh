#!/bin/bash
set -e

ROOTFS=${ROOT_MNT}
TOOLS=("zsh" "curl" "sudo")
MUSL_URL_BASE="https://musl.cc"

download_and_install() {
    tool=$1
    tarball="${tool}-static-x86_64.tar.xz"
    url="${MUSL_URL_BASE}/${tarball}"

    echo "⬇️  Downloading $tool from $url..."
    wget -q --show-progress "$url"

    echo "📦 Extracting $tarball..."
    tar -xf "$tarball"

    echo "📁 Installing $tool to $ROOTFS/bin/..."
    sudo cp ./${tool}-static-x86_64/bin/$tool "$ROOTFS/bin/"
    sudo chmod +x "$ROOTFS/bin/$tool"

    echo "🔗 Creating symlink in /usr/bin..."
    sudo mkdir -p "$ROOTFS/usr/bin"
    sudo ln -sf /bin/$tool "$ROOTFS/usr/bin/$tool"

    echo "✅ $tool installed successfully!"
    rm -rf "${tool}-static-x86_64" "$tarball"
}

for tool in "${TOOLS[@]}"; do
    download_and_install "$tool"
done

echo "🔧 All tools installed successfully!"