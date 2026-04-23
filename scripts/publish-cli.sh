#!/bin/bash
# Build and publish mecha10 CLI to Minio
#
# Builds the CLI for the current platform and uploads to Minio.
# Run this from a Mac after CI tag workflows go green to publish darwin binaries.
#
# Prerequisites:
#   - Rust toolchain installed (rustup)
#   - Docker installed (for minio/mc upload)
#   - MINIO_ACCESS_KEY and MINIO_SECRET_KEY set
#   - MECHA10_PATH environment variable set to mecha10 monorepo path
#
# Usage:
#   ./scripts/publish-cli.sh                              # Publish for native target
#   ./scripts/publish-cli.sh --target aarch64-apple-darwin
#   ./scripts/publish-cli.sh --all-darwin                 # Both darwin targets
#   ./scripts/publish-cli.sh --dry-run

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

MINIO_ENDPOINT="${MECHA10_MINIO_ENDPOINT:-http://192.168.1.32:9000}"
MINIO_BUCKET="${MECHA10_MINIO_BUCKET:-mecha10}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
TARGET=""
ALL_DARWIN=false
DRY_RUN=false

MECHA10_PATH="${MECHA10_PATH:-$HOME/src/laboratory-one/mecha10}"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --target TARGET      Rust target triple (default: native)"
    echo "  --all-darwin         Build and publish both darwin targets"
    echo "  --mecha10-path PATH  Path to mecha10 monorepo (default: \$MECHA10_PATH)"
    echo "  --dry-run            Show what would be done"
    echo "  --help               Show this help"
    echo ""
    echo "Environment:"
    echo "  MINIO_ACCESS_KEY     Minio access key (required)"
    echo "  MINIO_SECRET_KEY     Minio secret key (required)"
    echo "  MECHA10_MINIO_ENDPOINT  Minio endpoint (default: http://192.168.1.32:9000)"
    echo ""
    echo "Examples:"
    echo "  $0                               # Publish native target"
    echo "  $0 --all-darwin                  # Publish both darwin targets"
    echo "  $0 --target aarch64-apple-darwin # Publish Apple Silicon only"
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --target)
            TARGET="$2"
            shift 2
            ;;
        --all-darwin)
            ALL_DARWIN=true
            shift
            ;;
        --mecha10-path)
            MECHA10_PATH="$2"
            shift 2
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

# Verify mecha10 path
if [ ! -d "$MECHA10_PATH" ]; then
    echo -e "${RED}Error: mecha10 monorepo not found at: $MECHA10_PATH${NC}"
    echo "Set MECHA10_PATH or use --mecha10-path"
    exit 1
fi

# Check Minio credentials
if [ "$DRY_RUN" = false ]; then
    if [ -z "$MINIO_ACCESS_KEY" ] || [ -z "$MINIO_SECRET_KEY" ]; then
        echo -e "${RED}Error: MINIO_ACCESS_KEY and MINIO_SECRET_KEY must be set${NC}"
        exit 1
    fi
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker is required for Minio upload${NC}"
        exit 1
    fi
fi

VERSION=$(grep '^version = ' "$MECHA10_PATH/Cargo.toml" | head -1 | sed 's/version = "\(.*\)"/\1/')

# Determine targets to build
if [ "$ALL_DARWIN" = true ]; then
    TARGETS=("aarch64-apple-darwin" "x86_64-apple-darwin")
elif [ -n "$TARGET" ]; then
    TARGETS=("$TARGET")
else
    # Native
    case "$(uname -s)-$(uname -m)" in
        Darwin-arm64)   TARGETS=("aarch64-apple-darwin") ;;
        Darwin-x86_64)  TARGETS=("x86_64-apple-darwin") ;;
        Linux-x86_64)   TARGETS=("x86_64-unknown-linux-gnu") ;;
        Linux-aarch64)  TARGETS=("aarch64-unknown-linux-gnu") ;;
        *) echo -e "${RED}Error: Unknown platform${NC}"; exit 1 ;;
    esac
fi

target_to_os_arch() {
    case "$1" in
        aarch64-apple-darwin)        echo "darwin-aarch64" ;;
        x86_64-apple-darwin)         echo "darwin-x86_64" ;;
        x86_64-unknown-linux-gnu)    echo "linux-x86_64" ;;
        aarch64-unknown-linux-gnu)   echo "linux-aarch64" ;;
        *) echo "unknown" ;;
    esac
}

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}  Publish mecha10 CLI${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""
echo "Version:      v$VERSION"
echo "Targets:      ${TARGETS[*]}"
echo "Minio:        $MINIO_ENDPOINT/$MINIO_BUCKET/cli/"
echo "Mecha10 path: $MECHA10_PATH"
echo ""

[ "$DRY_RUN" = true ] && echo -e "${YELLOW}DRY RUN - No changes will be made${NC}\n"

BUILT_ARCHIVES=()

for BUILD_TARGET in "${TARGETS[@]}"; do
    OS_ARCH=$(target_to_os_arch "$BUILD_TARGET")
    ARCHIVE_NAME="mecha10-v${VERSION}-${OS_ARCH}.tar.gz"
    ARCHIVE_PATH="$MECHA10_PATH/dist/$ARCHIVE_NAME"

    echo -e "${BLUE}Building $BUILD_TARGET...${NC}"
    if [ "$DRY_RUN" = true ]; then
        echo "  Would build: $ARCHIVE_NAME"
    else
        "$SCRIPT_DIR/build-cli.sh" --target "$BUILD_TARGET" --mecha10-path "$MECHA10_PATH"
        BUILT_ARCHIVES+=("$ARCHIVE_PATH")
    fi
    echo ""
done

# Upload to Minio
if [ "$DRY_RUN" = false ] && [ ${#BUILT_ARCHIVES[@]} -gt 0 ]; then
    echo -e "${BLUE}Uploading to Minio...${NC}"
    for ARCHIVE_PATH in "${BUILT_ARCHIVES[@]}"; do
        ARCHIVE_NAME=$(basename "$ARCHIVE_PATH")
        echo "  Uploading $ARCHIVE_NAME..."
        docker run --rm \
            --entrypoint sh \
            -v "$MECHA10_PATH/dist:/dist" \
            minio/mc:latest -c "
                mc alias set minio '${MINIO_ENDPOINT}' '${MINIO_ACCESS_KEY}' '${MINIO_SECRET_KEY}'
                mc cp '/dist/${ARCHIVE_NAME}' 'minio/${MINIO_BUCKET}/cli/${ARCHIVE_NAME}'
            "
        echo -e "  ${GREEN}Uploaded: $ARCHIVE_NAME${NC}"
    done

    # Update latest.txt
    echo "$VERSION" > "$MECHA10_PATH/dist/cli-latest.txt"
    docker run --rm \
        --entrypoint sh \
        -v "$MECHA10_PATH/dist:/dist" \
        minio/mc:latest -c "
            mc alias set minio '${MINIO_ENDPOINT}' '${MINIO_ACCESS_KEY}' '${MINIO_SECRET_KEY}'
            mc cp '/dist/cli-latest.txt' 'minio/${MINIO_BUCKET}/cli/latest.txt'
        "
    echo -e "${GREEN}Updated cli/latest.txt → $VERSION${NC}"
elif [ "$DRY_RUN" = true ]; then
    for BUILD_TARGET in "${TARGETS[@]}"; do
        OS_ARCH=$(target_to_os_arch "$BUILD_TARGET")
        echo "  Would upload: mecha10-v${VERSION}-${OS_ARCH}.tar.gz"
    done
    echo "  Would update: cli/latest.txt → $VERSION"
fi

echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}  Done${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
