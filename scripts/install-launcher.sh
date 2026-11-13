#!/bin/sh

set -e

BINARY_NAME="mecha10-launcher"
INSTALL_DIR="${MECHA10_INSTALL_DIR:-$HOME/.local/bin}"
API_BASE="${MECHA10_API_URL:-https://mecha.industries/api}"
DATA_DIR="$HOME/.mecha10/launcher"
ROBOTS_DIR="$HOME/mecha10/robots"

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=scripts/lib/install-common.sh
. "$script_dir/lib/install-common.sh"

if [ -t 1 ]; then
    BOLD='\033[1m'
else
    BOLD=''
fi

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

    systemctl --user daemon-reload 2>/dev/null || true

    success "Created systemd service: $SERVICE_FILE"

    if command -v loginctl >/dev/null 2>&1; then
        info "Enabling user lingering for headless operation..."
        loginctl enable-linger "$(whoami)" 2>/dev/null || warn "Could not enable linger. Service may not run without active session."
    fi
}

main() {
    echo ""
    echo "${BOLD}=========================================="
    echo "  Mecha10 Launcher Installer"
    echo "==========================================${NC}"
    echo ""

    info "Detecting system..."
    OS=$(detect_os)
    if [ "$OS" != "linux" ]; then
        error "Unsupported operating system: $(uname -s). This installer only supports Linux."
    fi
    ARCH=$(detect_arch)

    info "OS: $OS, Architecture: $ARCH"

    info "Installing mecha10-launcher (version: ${MECHA10_VERSION:-latest})..."

    ARCHIVE_NAME="${BINARY_NAME}.tar.gz"
    DOWNLOAD_URL="${API_BASE}/downloads/launcher?arch=${ARCH}${MECHA10_VERSION:+&version=${MECHA10_VERSION}}"

    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' EXIT

    info "Downloading from ${DOWNLOAD_URL}..."
    download "$DOWNLOAD_URL" "$TMP_DIR/$ARCHIVE_NAME" || error "Failed to download. Check if release exists for your platform."

    info "Extracting..."
    tar -xzf "$TMP_DIR/$ARCHIVE_NAME" -C "$TMP_DIR"

    info "Creating directories..."
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$DATA_DIR"
    mkdir -p "$DATA_DIR/logs"
    mkdir -p "$ROBOTS_DIR"

    info "Installing to ${INSTALL_DIR}/${BINARY_NAME}..."
    mv "$TMP_DIR/${BINARY_NAME}" "$INSTALL_DIR/${BINARY_NAME}"
    chmod +x "$INSTALL_DIR/${BINARY_NAME}"

    if [ ! -x "$INSTALL_DIR/${BINARY_NAME}" ]; then
        error "Installation failed"
    fi

    success "Installed binary to ${INSTALL_DIR}/${BINARY_NAME}"

    if [ "${MECHA10_NO_SERVICE:-0}" != "1" ]; then
        setup_systemd_service
    fi

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
    success "mecha10-launcher installed successfully!"
    echo ""
    echo "Next steps:"
    echo ""
    echo "  1. Run the launcher:"
    echo "     ${BLUE}mecha10-launcher start${NC}"
    echo ""
    echo "     On first run, this walks you through interactive setup:"
    echo "     login (auth), then prompts for your robot project name and"
    echo "     robot ID. No manual config editing needed."
    echo ""
    echo "  2. Sync robot config (after setup):"
    echo "     ${BLUE}mecha10-launcher config pull${NC}"
    echo ""
    echo "  3. Or run as a service:"
    echo "     ${BLUE}systemctl --user start mecha10-launcher${NC}"
    echo "     ${BLUE}systemctl --user enable mecha10-launcher${NC}  # Start on boot"
    echo ""
}

main "$@"
