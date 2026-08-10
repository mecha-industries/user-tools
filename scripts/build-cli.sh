#!/bin/bash
# Build mecha10 CLI binary natively
#
# Builds the CLI for the current platform using cargo.
# For cross-compilation (e.g., building darwin-arm64 on darwin-x86_64),
# the appropriate Rust target must be installed.
#
# Prerequisites:
#   - Rust toolchain installed (rustup)
#   - MECHA10_PATH environment variable set to mecha10 monorepo path
#
# Usage:
#   ./scripts/build-cli.sh                              # Build for native target
#   ./scripts/build-cli.sh --target aarch64-apple-darwin
#   ./scripts/build-cli.sh --target x86_64-apple-darwin
#   ./scripts/build-cli.sh --mecha10-path ~/mecha10

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
TARGET=""

# Path to mecha10 monorepo
MECHA10_PATH="${MECHA10_PATH:-$HOME/src/laboratory-one/mecha10}"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --target TARGET      Rust target triple (default: native)"
    echo "  --mecha10-path PATH  Path to mecha10 monorepo (default: \$MECHA10_PATH)"
    echo "  --help               Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                                          # Build for native target"
    echo "  $0 --target aarch64-apple-darwin            # Build for Apple Silicon"
    echo "  $0 --target x86_64-apple-darwin             # Build for Intel Mac"
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --target)
            TARGET="$2"
            shift 2
            ;;
        --mecha10-path)
            MECHA10_PATH="$2"
            shift 2
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

# Verify mecha10 path exists
if [ ! -d "$MECHA10_PATH" ]; then
    echo -e "${RED}Error: mecha10 monorepo not found at: $MECHA10_PATH${NC}"
    echo ""
    echo "Set MECHA10_PATH or use --mecha10-path:"
    echo "  export MECHA10_PATH=~/src/laboratory-one/mecha10"
    exit 1
fi

# Map target to os-arch label
target_to_os_arch() {
    case "$1" in
        aarch64-apple-darwin)  echo "darwin-aarch64" ;;
        x86_64-apple-darwin)   echo "darwin-x86_64" ;;
        x86_64-unknown-linux-gnu)   echo "linux-x86_64" ;;
        aarch64-unknown-linux-gnu)  echo "linux-aarch64" ;;
        *) echo "unknown" ;;
    esac
}

# Detect native target
detect_native_target() {
    case "$(uname -s)-$(uname -m)" in
        Darwin-arm64)   echo "aarch64-apple-darwin" ;;
        Darwin-x86_64)  echo "x86_64-apple-darwin" ;;
        Linux-x86_64)   echo "x86_64-unknown-linux-gnu" ;;
        Linux-aarch64)  echo "aarch64-unknown-linux-gnu" ;;
        *) echo "" ;;
    esac
}

NATIVE_TARGET=$(detect_native_target)
BUILD_TARGET="${TARGET:-$NATIVE_TARGET}"

if [ -z "$BUILD_TARGET" ]; then
    echo -e "${RED}Error: Could not detect native target. Use --target to specify.${NC}"
    exit 1
fi

OS_ARCH=$(target_to_os_arch "$BUILD_TARGET")
VERSION=$(grep '^version = ' "$MECHA10_PATH/Cargo.toml" | head -1 | sed 's/version = "\(.*\)"/\1/')

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}  Build mecha10 CLI${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""
echo "Target:       $BUILD_TARGET ($OS_ARCH)"
echo "Version:      v$VERSION"
echo "Mecha10 path: $MECHA10_PATH"
echo ""

cd "$MECHA10_PATH"

# Install target if needed
if ! rustup target list --installed | grep -q "^${BUILD_TARGET}$"; then
    echo -e "${BLUE}Installing Rust target $BUILD_TARGET...${NC}"
    rustup target add "$BUILD_TARGET"
fi

# Build
echo -e "${BLUE}Building...${NC}"
if [ "$BUILD_TARGET" = "$NATIVE_TARGET" ]; then
    cargo build --release -p mecha10-cli
    BINARY_PATH="$MECHA10_PATH/target/release/mecha10"
else
    cargo build --release -p mecha10-cli --target "$BUILD_TARGET"
    BINARY_PATH="$MECHA10_PATH/target/$BUILD_TARGET/release/mecha10"
fi

if [ ! -f "$BINARY_PATH" ]; then
    echo -e "${RED}Error: Binary not found at $BINARY_PATH${NC}"
    exit 1
fi

# Package
mkdir -p "$MECHA10_PATH/dist"
ARCHIVE_NAME="mecha10-v${VERSION}-${OS_ARCH}.tar.gz"
ARCHIVE_PATH="$MECHA10_PATH/dist/$ARCHIVE_NAME"

tar -czf "$ARCHIVE_PATH" -C "$(dirname "$BINARY_PATH")" mecha10

SIZE=$(du -h "$ARCHIVE_PATH" | awk '{print $1}')

echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}  Build Complete${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo "Archive: $ARCHIVE_PATH"
echo "Size:    $SIZE"
echo ""
