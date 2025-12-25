#!/bin/bash
# Build and publish simulation Docker image to GHCR
#
# Prerequisites:
#   - Docker installed and running
#   - Authenticated to GHCR: echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
#
# Usage:
#   ./scripts/publish-simulation.sh 0.1.0        # Publish version 0.1.0
#   ./scripts/publish-simulation.sh 0.1.0 4.4    # Publish with Godot 4.4

set -e

VERSION="${1:-}"
GODOT_VERSION="${2:-4.3}"
REGISTRY="ghcr.io/mecha-industries/simulation"

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version> [godot-version]"
    echo ""
    echo "Examples:"
    echo "  $0 0.1.0           # Build with Godot 4.3 (default)"
    echo "  $0 0.2.0 4.4       # Build with Godot 4.4"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Build Simulation Image ==="
echo "Version: ${VERSION}"
echo "Godot: ${GODOT_VERSION}"
echo "Registry: ${REGISTRY}"
echo ""

# Build the image
echo "Building image..."
docker build \
    --build-arg GODOT_VERSION="${GODOT_VERSION}" \
    --build-arg GODOT_BUILD=stable \
    -t "${REGISTRY}:${VERSION}" \
    -t "${REGISTRY}:latest" \
    -t "${REGISTRY}:godot-${GODOT_VERSION}" \
    "${REPO_ROOT}/simulation"

echo ""
echo "=== Push to GHCR ==="

# Push all tags
docker push "${REGISTRY}:${VERSION}"
docker push "${REGISTRY}:latest"
docker push "${REGISTRY}:godot-${GODOT_VERSION}"

echo ""
echo "Published:"
echo "  ${REGISTRY}:${VERSION}"
echo "  ${REGISTRY}:latest"
echo "  ${REGISTRY}:godot-${GODOT_VERSION}"
