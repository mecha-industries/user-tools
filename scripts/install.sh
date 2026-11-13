#!/bin/sh

set -e

BINARY_NAME="mecha10"
INSTALL_DIR="${MECHA10_INSTALL_DIR:-$HOME/.local/bin}"
API_BASE="${MECHA10_API_URL:-https://mecha.industries/api}"

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=scripts/lib/install-common.sh
. "$script_dir/lib/install-common.sh"

main() {
    info "Detecting system..."
    OS=$(detect_os)
    ARCH=$(detect_arch)

    info "OS: $OS, Architecture: $ARCH"

    info "Installing mecha10 (version: ${MECHA10_VERSION:-latest})..."

    ARCHIVE_NAME="${BINARY_NAME}.tar.gz"
    DOWNLOAD_URL="${API_BASE}/downloads/cli?os=${OS}&arch=${ARCH}${MECHA10_VERSION:+&version=${MECHA10_VERSION}}"

    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' EXIT

    info "Downloading from ${DOWNLOAD_URL}..."
    download "$DOWNLOAD_URL" "$TMP_DIR/$ARCHIVE_NAME" || error "Failed to download. Check if release exists for your platform."

    info "Extracting..."
    tar -xzf "$TMP_DIR/$ARCHIVE_NAME" -C "$TMP_DIR"

    mkdir -p "$INSTALL_DIR"

    info "Installing to ${INSTALL_DIR}/${BINARY_NAME}..."
    mv "$TMP_DIR/${BINARY_NAME}" "$INSTALL_DIR/${BINARY_NAME}"
    chmod +x "$INSTALL_DIR/${BINARY_NAME}"

    if [ -x "$INSTALL_DIR/${BINARY_NAME}" ]; then
        success "Successfully installed mecha10 to ${INSTALL_DIR}/${BINARY_NAME}"
    else
        error "Installation failed"
    fi

    case ":$PATH:" in
        *":$INSTALL_DIR:"*)
            ;;
        *)
            warn "$INSTALL_DIR is not in your PATH"
            echo ""
            echo "Add it to your shell profile:"
            echo ""
            echo "  # For bash (~/.bashrc or ~/.bash_profile)"
            echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
            echo ""
            echo "  # For zsh (~/.zshrc)"
            echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
            echo ""
            echo "  # For fish (~/.config/fish/config.fish)"
            echo "  set -gx PATH \$HOME/.local/bin \$PATH"
            echo ""
            ;;
    esac

    echo ""
    success "Run 'mecha10 --help' to get started!"
}

main "$@"
