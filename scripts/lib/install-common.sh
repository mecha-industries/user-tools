#!/bin/sh
# scripts/lib/install-common.sh — helpers shared by install.sh and install-launcher.sh:
# colored logging (info/success/warn/error), OS/arch detection, and file download
# (curl with wget fallback). POSIX sh so it can be sourced from either script's
# #!/bin/sh shebang.

if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
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

# Full OS detection (Darwin/Linux/Windows). Callers that only support a subset
# (e.g. install-launcher.sh is Linux-only) should check the returned value
# themselves rather than relying on this to reject unsupported platforms.
detect_os() {
    case "$(uname -s)" in
        Darwin)
            echo "darwin"
            ;;
        Linux)
            echo "linux"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "windows"
            ;;
        *)
            error "Unsupported operating system: $(uname -s)"
            ;;
    esac
}

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

# verify_version — confirm the just-installed binary actually reports the
# version that was requested, instead of trusting a successful
# download+mv+chmod as proof the install is correct.
#
# Args:
#   $1 binary_path     - path to the installed executable
#   $2 expected_version - the version that was requested (e.g. $MECHA10_VERSION);
#                          pass "" if the caller requested "latest"/unset
#   $3 version_flag    - flag to query the binary's own version (default: --version)
#
# Behavior:
#   - Runs `<binary_path> <version_flag>` and extracts a semver-like token
#     from its output.
#   - If expected_version is non-empty, the extracted version must match it
#     (a leading "v" is ignored on either side) or this fails loudly.
#   - If expected_version is empty, just requires a non-empty, recognizable
#     version string to be reported.
#   - Returns 2 (without printing an error) if the binary doesn't support
#     version_flag at all, so callers whose binary is known not to implement
#     it can fall back to a weaker executability check instead of treating
#     this as a hard failure.
#   - Any other failure (binary ran but reported no recognizable version, or
#     reported a version that doesn't match) calls error(), which exits.
verify_version() {
    binary_path="$1"
    expected_version="$2"
    version_flag="${3:---version}"

    if ! version_output=$("$binary_path" "$version_flag" 2>&1); then
        return 2
    fi

    actual_version=$(printf '%s' "$version_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+[A-Za-z0-9.+-]*' | head -n1)

    if [ -z "$actual_version" ]; then
        error "Installed binary '$binary_path' ran '$version_flag' but reported no recognizable version string (output: '$version_output'). The download may be corrupt or incomplete."
    fi

    if [ -n "$expected_version" ]; then
        requested_version="${expected_version#v}"
        reported_version="${actual_version#v}"
        if [ "$requested_version" != "$reported_version" ]; then
            error "Version mismatch after install: requested '$expected_version' but installed binary '$binary_path' reports '$actual_version'. The download may be stale or corrupt — please retry."
        fi
    fi

    success "Verified installed binary reports version: $actual_version"
    return 0
}
