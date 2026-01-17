#!/bin/bash
# Build mecha10-launcher binary using Docker
#
# Builds the launcher for Linux (x86_64 or aarch64) using Docker-based
# cross-compilation. Outputs the binary to mecha10/dist/mecha10-launcher.
#
# Prerequisites:
#   - Docker installed and running
#   - MECHA10_PATH environment variable set to mecha10 monorepo path
#
# Usage:
#   ./scripts/build-launcher.sh                           # Build for x86_64 (default)
#   ./scripts/build-launcher.sh --arch aarch64            # Build for aarch64 (Pi 5)
#   ./scripts/build-launcher.sh --mecha10-path ~/mecha10  # Custom monorepo path

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
ARCH="x86_64"
NO_CACHE=false

# Path to mecha10 monorepo
MECHA10_PATH="${MECHA10_PATH:-$HOME/src/mecha-industries/mecha10}"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --arch ARCH          Target architecture: x86_64 (default) or aarch64"
    echo "  --mecha10-path PATH  Path to mecha10 monorepo (default: \$MECHA10_PATH)"
    echo "  --no-cache           Rebuild without Docker cache (use after code changes)"
    echo "  --help               Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                           # Build for x86_64"
    echo "  $0 --arch aarch64            # Build for aarch64 (Raspberry Pi 5)"
    echo "  $0 --arch aarch64 --no-cache # Rebuild after code changes"
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --mecha10-path)
            MECHA10_PATH="$2"
            shift 2
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Validate architecture
if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "aarch64" ]; then
    echo -e "${RED}Error: Invalid architecture '$ARCH'. Must be x86_64 or aarch64${NC}"
    exit 1
fi

# Verify mecha10 path exists
if [ ! -d "$MECHA10_PATH" ]; then
    echo -e "${RED}Error: mecha10 monorepo not found at: $MECHA10_PATH${NC}"
    echo ""
    echo "Set MECHA10_PATH or use --mecha10-path:"
    echo "  export MECHA10_PATH=~/src/laboratory-one/mecha10"
    echo "  $0 --mecha10-path ~/src/laboratory-one/mecha10"
    exit 1
fi

# Verify Dockerfile exists
DOCKERFILE="$MECHA10_PATH/docker/launcher-builder.Dockerfile"
if [ ! -f "$DOCKERFILE" ]; then
    echo -e "${RED}Error: Dockerfile not found at: $DOCKERFILE${NC}"
    exit 1
fi

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

IMAGE_NAME="mecha10-launcher-builder-${ARCH}"

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}  Build mecha10-launcher${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""
echo "Architecture: $ARCH"
echo "Mecha10 path: $MECHA10_PATH"
echo "Image name:   $IMAGE_NAME"
echo ""

# Build the Docker image
echo -e "${BLUE}Building Docker image...${NC}"
CACHE_FLAG=""
if [ "$NO_CACHE" = true ]; then
    echo -e "${YELLOW}Building without cache${NC}"
    CACHE_FLAG="--no-cache"
fi

docker build $CACHE_FLAG \
    -f "$DOCKERFILE" \
    --build-arg TARGET_ARCH="$ARCH" \
    -t "$IMAGE_NAME" \
    "$MECHA10_PATH"

# Create dist directory
mkdir -p "$MECHA10_PATH/dist"

# Extract the binary using docker cp (avoids QEMU issues with cross-arch containers)
echo ""
echo -e "${BLUE}Extracting binary...${NC}"
CONTAINER_ID=$(docker create "$IMAGE_NAME")
docker cp "$CONTAINER_ID:/mecha10-launcher" "$MECHA10_PATH/dist/mecha10-launcher"
docker rm "$CONTAINER_ID" > /dev/null
chmod +x "$MECHA10_PATH/dist/mecha10-launcher"

# Verify
if [ -f "$MECHA10_PATH/dist/mecha10-launcher" ]; then
    SIZE=$(du -h "$MECHA10_PATH/dist/mecha10-launcher" | awk '{print $1}')
    echo ""
    echo -e "${GREEN}==========================================${NC}"
    echo -e "${GREEN}  Build Complete${NC}"
    echo -e "${GREEN}==========================================${NC}"
    echo ""
    echo "Binary: $MECHA10_PATH/dist/mecha10-launcher"
    echo "Size:   $SIZE"
    echo "Arch:   $ARCH"
    echo ""
    echo "To test with e2e:"
    echo "  cd $MECHA10_PATH"
    if [ "$ARCH" = "aarch64" ]; then
        echo "  ./scripts/test-launcher-e2e.sh --arm64"
    else
        echo "  ./scripts/test-launcher-e2e.sh"
    fi
else
    echo -e "${RED}Error: Failed to extract binary${NC}"
    exit 1
fi
