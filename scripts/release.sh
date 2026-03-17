#!/bin/bash
set -euo pipefail

# MarkPush release script
# Usage: ./scripts/release.sh v1.0.0

VERSION="${1:?Usage: release.sh <version>}"

echo "==> Releasing MarkPush ${VERSION}"

# Verify clean working tree.
if [ -n "$(git status --porcelain)" ]; then
    echo "Error: working tree is not clean. Commit or stash changes first."
    exit 1
fi

# Verify tests pass.
echo "==> Running tests..."
cd cli && go test ./... -race && cd ..

# Tag and push.
echo "==> Creating tag ${VERSION}..."
git tag -a "${VERSION}" -m "Release ${VERSION}"
git push origin "${VERSION}"

echo ""
echo "✓ Tag ${VERSION} pushed. GitHub Actions will build and release."
echo "  Check: https://github.com/rahilsinghi/MarkPush/actions"
