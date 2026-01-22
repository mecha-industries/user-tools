#!/bin/sh
# Mecha10 Launcher Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/mecha-industries/user-tools/main/scripts/install-launcher.sh | sh
#
# This script installs the mecha10-launcher binary and sets up a user service.
#
# Environment variables:
#   MECHA10_VERSION       - Specific version to install (default: latest)
#   MECHA10_INSTALL_DIR   - Binary install location (default: ~/.local/bin)
#   MECHA10_NO_SERVICE    - Set to 1 to skip service setup

set -e

REPO="mecha-industries/user-tools"
BINARY_NAME="mecha10-launcher"
INSTALL_DIR="${MECHA10_INSTALL_DIR:-$HOME/.local/bin}"
DATA_DIR="$HOME/.mecha10/launcher"
ROBOTS_DIR="$HOME/mecha10/robots"

# Colors (disable if not a terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=''
    NC=''
fi

info() {
    printf "${BLUE}==>${NC} %s\n" "$1"
}

success() {
    printf "${GREEN}==>${NC} %s\n" "$1"
}

warn() {
    printf "${YELLOW}Warning:${NC} %s\n" "$1"
}

error() {
    printf "${RED}Error:${NC} %s\n" "$1" >&2
    exit 1
}

# Detect OS (Linux only)
detect_os() {
    case "$(uname -s)" in
        Linux)
            echo "linux"
            ;;
        *)
            error "Unsupported operating system: $(uname -s). This installer only supports Linux."
            ;;
    esac
}

# Detect architecture
detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)
            echo "x86_64"
            ;;
        arm64|aarch64)
            echo "aarch64"
            ;;
        *)
            error "Unsupported architecture: $(uname -m)"
            ;;
    esac
}

# Get latest release version from GitHub
get_latest_version() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/'
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/'
    else
        error "Neither curl nor wget found. Please install one of them."
    fi
}

# Download file
download() {
    url="$1"
    output="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$output"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$output"
    else
        error "Neither curl nor wget found. Please install one of them."
    fi
}

# Setup systemd user service (Linux)
setup_systemd_service() {
    SERVICE_DIR="$HOME/.config/systemd/user"
    SERVICE_FILE="$SERVICE_DIR/mecha10-launcher.service"

    info "Setting up systemd user service..."

    mkdir -p "$SERVICE_DIR"

    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Mecha10 Robot Launcher
Documentation=https://docs.mecha.industries
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/mecha10-launcher start --config ${DATA_DIR}/config.json
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

    # Reload systemd
    systemctl --user daemon-reload 2>/dev/null || true

    success "Created systemd service: $SERVICE_FILE"

    # Enable lingering so service runs without active session
    if command -v loginctl >/dev/null 2>&1; then
        info "Enabling user lingering for headless operation..."
        loginctl enable-linger "$(whoami)" 2>/dev/null || warn "Could not enable linger. Service may not run without active session."
    fi
}

# Create default configuration
create_default_config() {
    CONFIG_FILE="$DATA_DIR/config.json"

    if [ -f "$CONFIG_FILE" ]; then
        info "Configuration already exists: $CONFIG_FILE"
        return
    fi

    info "Creating default configuration..."

    cat > "$CONFIG_FILE" << EOF
{
  "robot_project": {
    "name": "robot_dev",
    "install_dir": "$ROBOTS_DIR"
  },
  "platform_url": "https://mecha.industries",
  "robot_id": "robot_dev",
  "device_id": "$(hostname)",
  "auto_update": true,
  "update_check_interval_seconds": 300,
  "binary_registry_url": "https://mecha.industries/api/builds"
}
EOF

    success "Created config: $CONFIG_FILE"
    warn "IMPORTANT: Edit 'robot_project.name' to match your project name before starting."
    echo "  The name must match the binary uploaded to the registry."
}

# Main installation
main() {
    echo ""
    echo "${BOLD}=========================================="
    echo "  Mecha10 Launcher Installer"
    echo "==========================================${NC}"
    echo ""

    info "Detecting system..."
    OS=$(detect_os)
    ARCH=$(detect_arch)

    info "OS: $OS, Architecture: $ARCH"

    # Get version (use provided or fetch latest)
    VERSION="${MECHA10_VERSION:-$(get_latest_version)}"
    if [ -z "$VERSION" ]; then
        error "Could not determine latest version. Please set MECHA10_VERSION environment variable."
    fi

    info "Installing mecha10-launcher ${VERSION}..."

    # Construct download URL
    ARCHIVE_NAME="${BINARY_NAME}-${VERSION}-${OS}-${ARCH}.tar.gz"
    DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${ARCHIVE_NAME}"

    # Create temp directory
    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' EXIT

    info "Downloading from ${DOWNLOAD_URL}..."
    download "$DOWNLOAD_URL" "$TMP_DIR/$ARCHIVE_NAME" || error "Failed to download. Check if release exists for your platform."

    # Extract
    info "Extracting..."
    tar -xzf "$TMP_DIR/$ARCHIVE_NAME" -C "$TMP_DIR"

    # Create directories
    info "Creating directories..."
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$DATA_DIR"
    mkdir -p "$DATA_DIR/logs"
    mkdir -p "$ROBOTS_DIR"

    # Install binary
    info "Installing to ${INSTALL_DIR}/${BINARY_NAME}..."
    mv "$TMP_DIR/${BINARY_NAME}" "$INSTALL_DIR/${BINARY_NAME}"
    chmod +x "$INSTALL_DIR/${BINARY_NAME}"

    # Verify installation
    if [ ! -x "$INSTALL_DIR/${BINARY_NAME}" ]; then
        error "Installation failed"
    fi

    success "Installed binary to ${INSTALL_DIR}/${BINARY_NAME}"

    # Create default configuration
    create_default_config

    # Setup systemd user service unless disabled
    if [ "${MECHA10_NO_SERVICE:-0}" != "1" ]; then
        setup_systemd_service
    fi

    # Check if install dir is in PATH
    case ":$PATH:" in
        *":$INSTALL_DIR:"*)
            ;;
        *)
            warn "$INSTALL_DIR is not in your PATH"
            echo ""
            echo "Add it to your shell profile:"
            echo ""
            echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
            echo ""
            ;;
    esac

    echo ""
    echo "${BOLD}=========================================="
    echo "  Installation Complete"
    echo "==========================================${NC}"
    echo ""
    success "mecha10-launcher ${VERSION} installed successfully!"
    echo ""
    echo "Next steps:"
    echo ""
    echo "  1. Login (if not already):"
    echo "     ${BLUE}mecha10-launcher auth login${NC}"
    echo ""
    echo "  2. Edit configuration:"
    echo "     ${BLUE}$DATA_DIR/config.json${NC}"
    echo ""
    echo "  3. Sync robot config:"
    echo "     ${BLUE}mecha10-launcher config pull${NC}"
    echo ""
    echo "  4. Start the service:"
    echo "     ${BLUE}systemctl --user start mecha10-launcher${NC}"
    echo "     ${BLUE}systemctl --user enable mecha10-launcher${NC}  # Start on boot"
    echo ""
    echo "  Or run manually:"
    echo "     ${BLUE}mecha10-launcher start${NC}"
    echo ""
}

main "$@"
