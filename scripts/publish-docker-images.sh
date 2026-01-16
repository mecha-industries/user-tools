#!/bin/bash
# Build and publish user-tools Docker images to GHCR
#
# Publishes:
#   - ghcr.io/mecha-industries/user-tools/dashboard
#   - ghcr.io/mecha-industries/user-tools/auth
#   - ghcr.io/mecha-industries/user-tools/websocket-relay
#
# Prerequisites:
#   - Docker installed and running
#   - Authenticated to GHCR: gh auth token | docker login ghcr.io -u USERNAME --password-stdin
#   - MECHA10_PATH environment variable set to mecha10 monorepo path
#
# Usage:
#   ./scripts/publish-docker-images.sh                    # Publish all
#   ./scripts/publish-docker-images.sh --version 0.1.44   # Publish specific version
#   ./scripts/publish-docker-images.sh --dashboard-only   # Publish only dashboard
#   ./scripts/publish-docker-images.sh --dry-run          # Show what would be done

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
REGISTRY="ghcr.io/mecha-industries/user-tools"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
VERSION=""
DRY_RUN=false
DASHBOARD_ONLY=false
AUTH_ONLY=false
RELAY_ONLY=false

# Path to mecha10 monorepo (where the Dockerfiles live)
MECHA10_PATH="${MECHA10_PATH:-$HOME/src/mecha-industries/mecha10}"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --version VERSION    Override version (default: from mecha10 Cargo.toml)"
    echo "  --mecha10-path PATH  Path to mecha10 monorepo (default: \$MECHA10_PATH or ~/src/mecha-industries/mecha10)"
    echo "  --dashboard-only     Only publish dashboard"
    echo "  --auth-only          Only publish auth"
    echo "  --relay-only         Only publish websocket-relay"
    echo "  --dry-run            Show what would be done"
    echo "  --help               Show this help"
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --mecha10-path)
            MECHA10_PATH="$2"
            shift 2
            ;;
        --dashboard-only)
            DASHBOARD_ONLY=true
            shift
            ;;
        --auth-only)
            AUTH_ONLY=true
            shift
            ;;
        --relay-only)
            RELAY_ONLY=true
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

# Verify mecha10 path exists
if [ ! -d "$MECHA10_PATH" ]; then
    echo -e "${RED}Error: mecha10 monorepo not found at: $MECHA10_PATH${NC}"
    echo ""
    echo "Set MECHA10_PATH or use --mecha10-path:"
    echo "  export MECHA10_PATH=~/src/laboratory-one/mecha10"
    echo "  $0 --mecha10-path ~/src/laboratory-one/mecha10"
    exit 1
fi

# Get version from Cargo.toml if not specified
if [ -z "$VERSION" ]; then
    VERSION=$(grep '^version = ' "$MECHA10_PATH/Cargo.toml" | head -1 | sed 's/version = "\(.*\)"/\1/')
fi

echo -e "${BLUE}=========================================="
echo "  Publish user-tools Images"
echo -e "==========================================${NC}"
echo ""
echo "Version:     $VERSION"
echo "Registry:    $REGISTRY"
echo "Mecha10:     $MECHA10_PATH"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}DRY RUN - No changes will be made${NC}"
    echo ""
fi

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Determine which images to build
BUILD_DASHBOARD=true
BUILD_AUTH=true
BUILD_RELAY=true

if [ "$DASHBOARD_ONLY" = true ]; then
    BUILD_AUTH=false
    BUILD_RELAY=false
elif [ "$AUTH_ONLY" = true ]; then
    BUILD_DASHBOARD=false
    BUILD_RELAY=false
elif [ "$RELAY_ONLY" = true ]; then
    BUILD_DASHBOARD=false
    BUILD_AUTH=false
fi

# Build and push function (monorepo context)
# Args: name, dockerfile_path (relative to MECHA10_PATH)
build_and_push() {
    local name=$1
    local dockerfile=$2
    local image="${REGISTRY}/${name}"

    echo -e "${BLUE}Building ${name}...${NC}"

    if [ "$DRY_RUN" = true ]; then
        echo "  Would build: ${image}:${VERSION}"
        echo "  Context:     ${MECHA10_PATH}"
        echo "  Dockerfile:  ${dockerfile}"
        echo "  Would push:  ${image}:${VERSION}"
        echo "  Would push:  ${image}:latest"
    else
        docker build \
            -f "${MECHA10_PATH}/${dockerfile}" \
            -t "${image}:${VERSION}" \
            -t "${image}:latest" \
            "$MECHA10_PATH"

        echo -e "${BLUE}Pushing ${name}...${NC}"
        docker push "${image}:${VERSION}"
        docker push "${image}:latest"

        echo -e "${GREEN}Published ${image}:${VERSION}${NC}"
    fi
    echo ""
}

# Build and push function (standalone service context)
# Args: name, service_path (relative to MECHA10_PATH)
build_and_push_standalone() {
    local name=$1
    local service_path=$2
    local image="${REGISTRY}/${name}"
    local context="${MECHA10_PATH}/${service_path}"

    echo -e "${BLUE}Building ${name}...${NC}"

    if [ "$DRY_RUN" = true ]; then
        echo "  Would build: ${image}:${VERSION}"
        echo "  Context:     ${context}"
        echo "  Would push:  ${image}:${VERSION}"
        echo "  Would push:  ${image}:latest"
    else
        docker build \
            -t "${image}:${VERSION}" \
            -t "${image}:latest" \
            "$context"

        echo -e "${BLUE}Pushing ${name}...${NC}"
        docker push "${image}:${VERSION}"
        docker push "${image}:latest"

        echo -e "${GREEN}Published ${image}:${VERSION}${NC}"
    fi
    echo ""
}

# Build and push images
if [ "$BUILD_DASHBOARD" = true ]; then
    build_and_push "dashboard" "packages/dashboard/Dockerfile"
fi

if [ "$BUILD_AUTH" = true ]; then
    build_and_push "auth" "packages/services/auth/Dockerfile"
fi

if [ "$BUILD_RELAY" = true ]; then
    build_and_push_standalone "websocket-relay" "packages/services/websocket-relay"
fi

echo -e "${GREEN}=========================================="
echo "  Publish Complete"
echo -e "==========================================${NC}"
echo ""
echo "Published images:"
if [ "$BUILD_DASHBOARD" = true ]; then
    echo "  ${REGISTRY}/dashboard:${VERSION}"
fi
if [ "$BUILD_AUTH" = true ]; then
    echo "  ${REGISTRY}/auth:${VERSION}"
fi
if [ "$BUILD_RELAY" = true ]; then
    echo "  ${REGISTRY}/websocket-relay:${VERSION}"
fi
echo ""
