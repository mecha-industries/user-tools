#!/bin/sh
#
# Usage:
#   install-launcher.sh [--mode local]
#   install-launcher.sh --mode ssh --host <host> [--user <user>] --ssh-password <password> \
#       [--env-file <path>]
#
# local mode (default) runs the install directly on this machine — the
# existing curl-on-device behavior, unchanged.
#
# ssh mode connects to the robot over SSH using password auth (via sshpass)
# and runs the same public install one-liner remotely, forwarding through
# any of MECHA10_VERSION/MECHA10_NO_SERVICE/MECHA10_API_URL set locally.
#
# Env vars (each overridable by the matching --flag, ssh mode only):
#   MECHA10_ROBOT_HOST        robot host/IP, reachable over ethernet
#   MECHA10_ROBOT_USER        SSH login username (default: pi)
#   MECHA10_ROBOT_PASSWORD    SSH login password, used via sshpass
#   MECHA10_ROBOT_ENV_FILE    optional .env-style file to source for the above

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

usage() {
    cat <<EOF
Usage:
  install-launcher.sh [--mode local]
  install-launcher.sh --mode ssh --host <host> [--user <user>] --ssh-password <password> \\
      [--env-file <path>]

Options:
  --mode <local|ssh>       Install mode (default: local)
  --host <host>            Robot host/IP, reachable over ethernet (ssh mode, or MECHA10_ROBOT_HOST)
  --user <user>            SSH login username (ssh mode, default: pi, or MECHA10_ROBOT_USER)
  --ssh-password <password>
                           SSH login password, used via sshpass (ssh mode, required, or
                           MECHA10_ROBOT_PASSWORD)
  --env-file <path>        .env-style file to source first (or MECHA10_ROBOT_ENV_FILE)
  -h, --help               Show this help

local mode (default) installs directly on this machine — identical to running
the public curl one-liner, and unaffected by any of the options above.

ssh mode connects to the robot over SSH using password auth (sshpass) and
runs the same install remotely, forwarding through any of MECHA10_VERSION/
MECHA10_NO_SERVICE/MECHA10_API_URL that are set in your local environment.
EOF
}

MODE="local"
ROBOT_HOST="${MECHA10_ROBOT_HOST:-}"
ROBOT_USER="${MECHA10_ROBOT_USER:-pi}"
ROBOT_PASSWORD="${MECHA10_ROBOT_PASSWORD:-}"
ENV_FILE="${MECHA10_ROBOT_ENV_FILE:-}"

while [ $# -gt 0 ]; do
    case "$1" in
        --mode)
            MODE="$2"
            shift 2
            ;;
        --host)
            ROBOT_HOST="$2"
            shift 2
            ;;
        --user)
            ROBOT_USER="$2"
            shift 2
            ;;
        --ssh-password)
            ROBOT_PASSWORD="$2"
            shift 2
            ;;
        --env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown argument: $1"
            ;;
    esac
done

if [ -n "$ENV_FILE" ]; then
    [ -f "$ENV_FILE" ] || error "--env-file '$ENV_FILE' not found"
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    ROBOT_HOST="${ROBOT_HOST:-$MECHA10_ROBOT_HOST}"
    ROBOT_USER="${ROBOT_USER:-${MECHA10_ROBOT_USER:-pi}}"
    ROBOT_PASSWORD="${ROBOT_PASSWORD:-$MECHA10_ROBOT_PASSWORD}"
fi

install_via_ssh() {
    [ -n "$ROBOT_HOST" ] || { usage; error "--host is required for --mode ssh"; }
    [ -n "$ROBOT_PASSWORD" ] || { usage; error "--ssh-password is required for --mode ssh"; }
    command -v sshpass >/dev/null || error "sshpass is required for --mode ssh — install it (e.g. 'brew install sshpass' on macOS, 'apt install sshpass' on Linux) and retry"

    TARGET="$ROBOT_USER@$ROBOT_HOST"

    REMOTE_ENV=""
    [ -n "${MECHA10_VERSION:-}" ] && REMOTE_ENV="$REMOTE_ENV MECHA10_VERSION='$MECHA10_VERSION'"
    [ -n "${MECHA10_NO_SERVICE:-}" ] && REMOTE_ENV="$REMOTE_ENV MECHA10_NO_SERVICE='$MECHA10_NO_SERVICE'"
    [ -n "${MECHA10_API_URL:-}" ] && REMOTE_ENV="$REMOTE_ENV MECHA10_API_URL='$MECHA10_API_URL'"

    info "Installing mecha10-launcher on $TARGET over SSH..."

    sshpass -p "$ROBOT_PASSWORD" ssh -o StrictHostKeyChecking=accept-new "$TARGET" \
        "${REMOTE_ENV# } sh -c 'curl -fsSL https://mecha.industries/api/install-launcher.sh | sh'"

    success "mecha10-launcher installed on $TARGET"
}

if [ "$MODE" = "ssh" ]; then
    install_via_ssh
    exit 0
fi

[ "$MODE" = "local" ] || { usage; error "Unknown --mode '$MODE' (expected local or ssh)"; }

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

    info "Verifying installed version..."
    if ! verify_version "$INSTALL_DIR/${BINARY_NAME}" "$MECHA10_VERSION" "--version"; then
        # mecha10-launcher does not currently implement --version (no
        # #[command(version)] on its CLI), so we can't do a strict
        # version-match check here. Fall back to confirming the binary is
        # at least a valid, runnable executable rather than silently
        # trusting that mv+chmod succeeded.
        warn "mecha10-launcher does not support --version; skipping strict version verification."
        if ! "$INSTALL_DIR/${BINARY_NAME}" --help >/dev/null 2>&1; then
            error "Installed mecha10-launcher binary failed to run (--help failed). The download or install may be corrupt — please retry."
        fi
    fi

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
