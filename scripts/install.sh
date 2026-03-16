#!/bin/bash
set -euo pipefail

# MarkPush installer
# Usage: curl -fsSL https://raw.githubusercontent.com/rahilsinghi/MarkPush/main/scripts/install.sh | bash

REPO="rahilsinghi/MarkPush"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "==> Detecting system: ${OS}/${ARCH}"

# Get latest release tag
LATEST=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
echo "==> Latest release: ${LATEST}"

# Download
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${LATEST}/markpush-${OS}-${ARCH}.tar.gz"
echo "==> Downloading from ${DOWNLOAD_URL}..."

TMP=$(mktemp -d)
curl -fsSL "${DOWNLOAD_URL}" | tar xz -C "${TMP}"

# Install
echo "==> Installing to ${INSTALL_DIR}/markpush"
sudo mv "${TMP}/markpush" "${INSTALL_DIR}/markpush"
rm -rf "${TMP}"

echo ""
echo "✓ markpush installed successfully!"
echo ""
echo "Next steps:"
echo "  1. Run 'markpush pair' to pair with your iPhone"
echo "  2. Run 'markpush push file.md' to push a document"
