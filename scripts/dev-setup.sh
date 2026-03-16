#!/bin/bash
set -euo pipefail

echo "==> Setting up MarkPush development environment"

# Check Go
if command -v go &>/dev/null; then
    echo "  ✓ Go $(go version | awk '{print $3}')"
else
    echo "  ✗ Go not found. Install from https://go.dev/dl/"
    exit 1
fi

# Install Go tools
echo "==> Installing Go tools..."
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
echo "  ✓ golangci-lint"

# Check Xcode (macOS only)
if [[ "$(uname)" == "Darwin" ]]; then
    if command -v xcodebuild &>/dev/null; then
        echo "  ✓ Xcode $(xcodebuild -version | head -1)"
    else
        echo "  ⚠ Xcode not found (optional — needed for iOS development)"
    fi

    # Install Swift tools
    if command -v brew &>/dev/null; then
        echo "==> Installing Swift tools via Homebrew..."
        brew install swiftlint swiftformat xcbeautify 2>/dev/null || true
        echo "  ✓ swiftlint, swiftformat, xcbeautify"
    fi
fi

# Set up Go modules
echo "==> Setting up Go modules..."
cd cli && go mod download && cd ..
echo "  ✓ Go dependencies downloaded"

# Verify build
echo "==> Verifying build..."
make build
echo "  ✓ CLI builds successfully"

echo ""
echo "==> Development environment ready!"
echo "    Run 'make help' to see available commands."
