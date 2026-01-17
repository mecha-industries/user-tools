#!/bin/bash
# Build and publish mecha10-launcher to GitHub releases
#
# Builds the launcher for the specified architecture and uploads
# to GitHub releases on mecha-industries/user-tools.
#
# Prerequisites:
#   - Docker installed and running
#   - gh CLI authenticated
#   - MECHA10_PATH environment variable set to mecha10 monorepo path
#
# Usage:
#   ./scripts/publish-launcher.sh                           # Publish for aarch64 (default)
#   ./scripts/publish-launcher.sh --arch x86_64             # Publish for x86_64
#   ./scripts/publish-launcher.sh --version 0.1.45          # Specific version
#   ./scripts/publish-launcher.sh --dry-run                 # Show what would be done

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="mecha-industries/user-tools"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
ARCH="aarch64"
VERSION=""
DRY_RUN=false
NO_CACHE=false

# Path to mecha10 monorepo
MECHA10_PATH="${MECHA10_PATH:-$HOME/src/laboratory-one/mecha10}"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --arch ARCH          Target architecture: aarch64 (default) or x86_64"
    echo "  --version VERSION    Version to publish (default: from Cargo.toml)"
    echo "  --mecha10-path PATH  Path to mecha10 monorepo (default: \$MECHA10_PATH)"
    echo "  --no-cache           Rebuild without Docker cache"
    echo "  --dry-run            Show what would be done"
    echo "  --help               Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                              # Build and publish aarch64"
    echo "  $0 --arch x86_64                # Build and publish x86_64"
    echo "  $0 --version 0.1.45 --no-cache  # Rebuild specific version"
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
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
        --dry-run)
            DRY_RUN=true
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
    exit 1
fi

# Get version from Cargo.toml if not specified
if [ -z "$VERSION" ]; then
    VERSION=$(grep '^version = ' "$MECHA10_PATH/Cargo.toml" | head -1 | sed 's/version = "\(.*\)"/\1/')
fi

# Check gh CLI
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: gh CLI is not installed${NC}"
    exit 1
fi

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}  Publish mecha10-launcher${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""
echo "Version:      v${VERSION}"
echo "Architecture: ${ARCH}"
echo "Repository:   ${REPO}"
echo "Mecha10 path: ${MECHA10_PATH}"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}DRY RUN - No changes will be made${NC}"
    echo ""
fi

# Step 1: Build the launcher
echo -e "${BLUE}Step 1: Building launcher...${NC}"

BUILD_FLAGS=""
if [ "$NO_CACHE" = true ]; then
    BUILD_FLAGS="--no-cache"
fi

if [ "$DRY_RUN" = true ]; then
    echo "  Would run: $SCRIPT_DIR/build-launcher.sh --arch $ARCH $BUILD_FLAGS"
else
    "$SCRIPT_DIR/build-launcher.sh" --arch "$ARCH" $BUILD_FLAGS --mecha10-path "$MECHA10_PATH"
fi
echo ""

# Verify binary was built
BINARY_PATH="$MECHA10_PATH/dist/mecha10-launcher"
if [ "$DRY_RUN" = false ] && [ ! -f "$BINARY_PATH" ]; then
    echo -e "${RED}Error: Binary not found at $BINARY_PATH${NC}"
    exit 1
fi

# Step 2: Verify binary architecture
echo -e "${BLUE}Step 2: Verifying binary architecture...${NC}"
if [ "$DRY_RUN" = false ]; then
    BINARY_INFO=$(file "$BINARY_PATH")
    echo "  $BINARY_INFO"

    if [ "$ARCH" = "aarch64" ]; then
        if ! echo "$BINARY_INFO" | grep -q "ARM aarch64"; then
            echo -e "${RED}Error: Binary is not aarch64${NC}"
            exit 1
        fi
    elif [ "$ARCH" = "x86_64" ]; then
        if ! echo "$BINARY_INFO" | grep -q "x86-64"; then
            echo -e "${RED}Error: Binary is not x86_64${NC}"
            exit 1
        fi
    fi
    echo -e "  ${GREEN}Architecture verified${NC}"
else
    echo "  Would verify binary architecture"
fi
echo ""

# Step 3: Create tarball
echo -e "${BLUE}Step 3: Creating tarball...${NC}"
ARCHIVE_NAME="mecha10-launcher-v${VERSION}-linux-${ARCH}.tar.gz"
ARCHIVE_PATH="$MECHA10_PATH/dist/$ARCHIVE_NAME"

if [ "$DRY_RUN" = true ]; then
    echo "  Would create: $ARCHIVE_PATH"
else
    tar -czvf "$ARCHIVE_PATH" -C "$MECHA10_PATH/dist" mecha10-launcher
    echo -e "  ${GREEN}Created: $ARCHIVE_PATH${NC}"
fi
echo ""

# Step 4: Create or verify GitHub release
echo -e "${BLUE}Step 4: Checking GitHub release...${NC}"
if [ "$DRY_RUN" = true ]; then
    echo "  Would check/create release v${VERSION}"
else
    if gh release view "v${VERSION}" --repo "$REPO" > /dev/null 2>&1; then
        echo "  Release v${VERSION} exists"
    else
        echo "  Creating release v${VERSION}..."
        gh release create "v${VERSION}" --repo "$REPO" --title "v${VERSION}" --notes "Release v${VERSION}"
        echo -e "  ${GREEN}Release created${NC}"
    fi
fi
echo ""

# Step 5: Upload tarball
echo -e "${BLUE}Step 5: Uploading to GitHub release...${NC}"
if [ "$DRY_RUN" = true ]; then
    echo "  Would upload: $ARCHIVE_NAME"
else
    gh release upload "v${VERSION}" "$ARCHIVE_PATH" --repo "$REPO" --clobber
    echo -e "  ${GREEN}Uploaded: $ARCHIVE_NAME${NC}"
fi
echo ""

# Done
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}  Publish Complete${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo "Install with:"
echo "  curl -fsSL https://raw.githubusercontent.com/${REPO}/main/scripts/install-launcher.sh | sh"
echo ""
