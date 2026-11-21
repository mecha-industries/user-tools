#!/bin/bash
# camera-test.sh — hardware diagnostic for a robot's camera: either the Pi's
# CSI camera module (via rpicam-apps) or a USB webcam (via ffmpeg/v4l2-ctl).
#
# Modes:
#   csi   Test the Pi's CSI camera module. Checks availability via
#         `vcgencmd get_camera` (falling back to `rpicam-hello --list-cameras`
#         if vcgencmd isn't available or reports nothing), then captures a
#         single still with `rpicam-still`.
#   usb   Test a USB webcam at a /dev/videoN device. Captures a single frame
#         with `ffmpeg`.
#   auto  (default) Prefer CSI if a camera is detected there; otherwise fall
#         back to the first USB camera device found.
#
# Usage:
#   camera-test.sh [--mode csi|usb|auto] [--device /dev/videoN] [--out <dir>] [--list]
#
# Options:
#   --mode <csi|usb|auto>   Which camera to test (default: auto)
#   --device <path>         USB device to use (usb mode, default: first detected)
#   --out <dir>             Output directory for captures (default: $HOME/captures,
#                           created if missing)
#   --list                  List detected USB video devices and exit (no capture)
#   -h, --help              Show this help
#
# On success, prints the path of the saved capture
# (<out-dir>/capture_<timestamp>.jpg). Exits non-zero with a clear, specific
# message on any failure (missing tool, no camera found, capture failure).
#
# Requires: `rpicam-apps` (rpicam-still/rpicam-hello) for CSI mode; `ffmpeg`
# and, optionally, `v4l2-ctl` (from `v4l-utils`, used for device discovery —
# falls back to a /dev/video* glob if not installed) for USB mode.

set -e

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=scripts/lib/install-common.sh
. "$script_dir/../../lib/install-common.sh"

usage() {
    cat <<EOF
Usage:
  camera-test.sh [--mode csi|usb|auto] [--device /dev/videoN] [--out <dir>] [--list]

Options:
  --mode <csi|usb|auto>   Which camera to test (default: auto — prefer CSI if detected,
                          else the first USB camera found)
  --device <path>         USB video device to use (usb mode, default: first device found
                          via 'v4l2-ctl --list-devices', or a /dev/video* glob if
                          v4l2-ctl isn't installed)
  --out <dir>             Output directory for captures (default: \$HOME/captures,
                          created if missing)
  --list                  List detected USB video devices and exit, without capturing
  -h, --help              Show this help

csi mode checks camera availability via 'vcgencmd get_camera' (falling back to
'rpicam-hello --list-cameras' if vcgencmd is unavailable or reports nothing detected),
then captures a single still with 'rpicam-still'. Requires rpicam-apps.

usb mode captures a single frame from a /dev/videoN device with ffmpeg. Requires ffmpeg,
and optionally v4l2-ctl (from v4l-utils) for device discovery.

auto mode (default) prefers csi if a camera is detected there, otherwise falls back to
the first USB camera device found.

On success, prints the path of the saved capture (<out-dir>/capture_<timestamp>.jpg).
EOF
}

MODE="auto"
DEVICE=""
OUT_DIR="${HOME}/captures"
LIST_ONLY=0

while [ $# -gt 0 ]; do
    case "$1" in
        --mode)
            MODE="$2"
            shift 2
            ;;
        --device)
            DEVICE="$2"
            shift 2
            ;;
        --out)
            OUT_DIR="$2"
            shift 2
            ;;
        --list)
            LIST_ONLY=1
            shift
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

case "$MODE" in
    csi|usb|auto) ;;
    *)
        usage
        error "Unknown --mode '$MODE' (expected csi, usb, or auto)"
        ;;
esac

timestamp() {
    date +%Y%m%d_%H%M%S
}

list_usb_devices() {
    if command -v v4l2-ctl >/dev/null 2>&1; then
        v4l2-ctl --list-devices
    else
        for dev in /dev/video*; do
            [ -e "$dev" ] && echo "$dev"
        done
    fi
}

first_usb_device() {
    if command -v v4l2-ctl >/dev/null 2>&1; then
        v4l2-ctl --list-devices 2>/dev/null | grep -oE '/dev/video[0-9]+' | head -n1
    else
        for dev in /dev/video0 /dev/video1 /dev/video2 /dev/video3 /dev/video4 /dev/video5 /dev/video6 /dev/video7 /dev/video8 /dev/video9; do
            if [ -e "$dev" ]; then
                echo "$dev"
                return 0
            fi
        done
    fi
}

csi_camera_detected() {
    if command -v vcgencmd >/dev/null 2>&1; then
        if vcgencmd get_camera 2>/dev/null | grep -q "detected=1"; then
            return 0
        fi
    fi

    if command -v rpicam-hello >/dev/null 2>&1; then
        if rpicam-hello --list-cameras 2>&1 | grep -qE '^\s*[0-9]+\s*:'; then
            return 0
        fi
    fi

    return 1
}

test_csi() {
    command -v rpicam-still >/dev/null 2>&1 || error "rpicam-still not found — install rpicam-apps (e.g. 'sudo apt install rpicam-apps') and retry"

    if ! csi_camera_detected; then
        if command -v rpicam-hello >/dev/null 2>&1; then
            LIST_OUTPUT="$(rpicam-hello --list-cameras 2>&1 || true)"
            if printf '%s' "$LIST_OUTPUT" | grep -qi "no cameras available"; then
                error "No camera detected — check ribbon cable and connector."
            elif printf '%s' "$LIST_OUTPUT" | grep -qi "camera is disabled"; then
                error "Camera is disabled — run 'sudo raspi-config' and enable it."
            fi
        fi
        error "No camera detected — check ribbon cable and connector."
    fi

    mkdir -p "$OUT_DIR"
    OUT_FILE="$OUT_DIR/capture_$(timestamp).jpg"

    info "Capturing from CSI camera..."
    if ! rpicam-still -o "$OUT_FILE" --nopreview -t 1000; then
        error "rpicam-still failed to capture an image — is the camera in use by another process?"
    fi

    [ -s "$OUT_FILE" ] || error "rpicam-still reported success but '$OUT_FILE' is missing or empty"

    success "Saved CSI camera capture: $OUT_FILE"
}

test_usb() {
    command -v ffmpeg >/dev/null 2>&1 || error "ffmpeg not found — install it (e.g. 'sudo apt install ffmpeg') and retry"

    if [ -z "$DEVICE" ]; then
        DEVICE="$(first_usb_device)"
        [ -n "$DEVICE" ] || error "No USB video device found — check the webcam is plugged in (expected a /dev/video* device, optionally discoverable via 'v4l2-ctl --list-devices')"
    fi

    [ -e "$DEVICE" ] || error "USB video device '$DEVICE' does not exist"

    mkdir -p "$OUT_DIR"
    OUT_FILE="$OUT_DIR/capture_$(timestamp).jpg"

    info "Capturing from USB camera at $DEVICE..."
    if ! ffmpeg -y -f v4l2 -i "$DEVICE" -frames:v 1 "$OUT_FILE" >/dev/null 2>&1; then
        error "ffmpeg failed to capture from '$DEVICE' — the device may be busy/in use by another process, or not a valid video capture device"
    fi

    [ -s "$OUT_FILE" ] || error "ffmpeg reported success but '$OUT_FILE' is missing or empty"

    success "Saved USB camera capture: $OUT_FILE"
}

if [ "$LIST_ONLY" -eq 1 ]; then
    list_usb_devices
    exit 0
fi

case "$MODE" in
    csi)
        test_csi
        ;;
    usb)
        test_usb
        ;;
    auto)
        if csi_camera_detected; then
            info "Auto mode: CSI camera detected, testing CSI..."
            test_csi
        else
            info "Auto mode: no CSI camera detected, falling back to USB..."
            test_usb
        fi
        ;;
esac
