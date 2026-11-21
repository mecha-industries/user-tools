#!/bin/bash
# wifi-update.sh — update a robot's wifi connection in one of two modes:
#
#   ssh     Connect to a robot over ethernet (so it stays reachable even if
#           the new wifi credentials turn out to be wrong) and use nmcli to
#           create/replace a NetworkManager wifi connection profile, then
#           bring it up.
#   offline Write a NetworkManager wifi connection profile directly onto a
#           mounted (not currently booted) SD card or USB boot disk for
#           Raspberry Pi OS Bookworm+ (NetworkManager-based), so the device
#           joins the given network automatically on its next boot.
#
# Usage:
#   wifi-update.sh --mode ssh --host <host> --ssid <ssid> --password <password> [--iface <iface>]
#   wifi-update.sh --mode offline --mount <path> --ssid <ssid> --password <password>
#
# Env vars (each overridable by the matching --flag):
#   MECHA10_WIFI_MODE       ssh | offline
#   MECHA10_WIFI_HOST       robot host/IP, reachable over ethernet (ssh mode)
#   MECHA10_WIFI_IFACE      wifi interface name on the robot (ssh mode, default: wlan0)
#   MECHA10_WIFI_MOUNT      mount path of the boot SD card/USB disk (offline mode)
#   MECHA10_WIFI_SSID       wifi network name
#   MECHA10_WIFI_PASSWORD   wifi password
#   MECHA10_WIFI_ENV_FILE   optional .env-style file to source for the above

set -e

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=scripts/lib/install-common.sh
. "$script_dir/../../lib/install-common.sh"

usage() {
    cat <<EOF
Usage:
  wifi-update.sh --mode ssh --host <host> --ssid <ssid> --password <password> [--iface <iface>]
  wifi-update.sh --mode offline --mount <path> --ssid <ssid> --password <password>

Options:
  --mode <ssh|offline>   Update mode (or MECHA10_WIFI_MODE)
  --host <host>          Robot host/IP, reachable over ethernet (ssh mode, or MECHA10_WIFI_HOST)
  --iface <iface>        Wifi interface on the robot (ssh mode, default: wlan0, or MECHA10_WIFI_IFACE)
  --mount <path>         Mount path of the boot SD card/USB disk (offline mode, or MECHA10_WIFI_MOUNT)
  --ssid <ssid>          Wifi network name (or MECHA10_WIFI_SSID)
  --password <password>  Wifi password (or MECHA10_WIFI_PASSWORD)
  --env-file <path>      .env-style file to source first (or MECHA10_WIFI_ENV_FILE)
  -h, --help             Show this help

ssh mode runs over ethernet, so the robot stays reachable even if the new
wifi credentials turn out to be wrong.

offline mode expects <path> to be the root of an already-mounted (not
currently booted) Raspberry Pi OS Bookworm+ filesystem — the profile is
written under <path>/etc/NetworkManager/system-connections/.
EOF
}

MODE="${MECHA10_WIFI_MODE:-}"
HOST="${MECHA10_WIFI_HOST:-}"
IFACE="${MECHA10_WIFI_IFACE:-wlan0}"
MOUNT_PATH="${MECHA10_WIFI_MOUNT:-}"
SSID="${MECHA10_WIFI_SSID:-}"
PASSWORD="${MECHA10_WIFI_PASSWORD:-}"
ENV_FILE="${MECHA10_WIFI_ENV_FILE:-}"

while [ $# -gt 0 ]; do
    case "$1" in
        --mode)
            MODE="$2"
            shift 2
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        --iface)
            IFACE="$2"
            shift 2
            ;;
        --mount)
            MOUNT_PATH="$2"
            shift 2
            ;;
        --ssid)
            SSID="$2"
            shift 2
            ;;
        --password)
            PASSWORD="$2"
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
    MODE="${MODE:-$MECHA10_WIFI_MODE}"
    HOST="${HOST:-$MECHA10_WIFI_HOST}"
    IFACE="${IFACE:-${MECHA10_WIFI_IFACE:-wlan0}}"
    MOUNT_PATH="${MOUNT_PATH:-$MECHA10_WIFI_MOUNT}"
    SSID="${SSID:-$MECHA10_WIFI_SSID}"
    PASSWORD="${PASSWORD:-$MECHA10_WIFI_PASSWORD}"
fi

[ -n "$MODE" ] || { usage; error "--mode (ssh|offline) is required"; }
[ -n "$SSID" ] || { usage; error "--ssid is required"; }
[ -n "$PASSWORD" ] || { usage; error "--password is required"; }

update_via_ssh() {
    [ -n "$HOST" ] || { usage; error "--host is required for --mode ssh"; }

    info "Updating wifi connection '$SSID' on $HOST over ethernet (iface: $IFACE)..."

    ssh -o BatchMode=yes "$HOST" "bash -s" <<REMOTE
set -e
if nmcli -t -f NAME connection show | grep -Fxq "$SSID"; then
    nmcli connection delete "$SSID"
fi
nmcli connection add type wifi con-name "$SSID" ifname "$IFACE" ssid "$SSID" \\
    wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$PASSWORD" connection.autoconnect yes
nmcli connection up "$SSID"
REMOTE

    success "Wifi connection '$SSID' updated and brought up on $HOST"
}

update_offline() {
    [ -n "$MOUNT_PATH" ] || { usage; error "--mount is required for --mode offline"; }
    [ -d "$MOUNT_PATH" ] || error "Mount path '$MOUNT_PATH' does not exist or is not a directory"

    CONN_DIR="$MOUNT_PATH/etc/NetworkManager/system-connections"
    [ -d "$CONN_DIR" ] || error "'$CONN_DIR' not found — is '$MOUNT_PATH' a mounted Raspberry Pi OS Bookworm+ (NetworkManager-based) rootfs?"

    CONN_FILE="$CONN_DIR/${SSID}.nmconnection"

    info "Writing wifi connection profile for '$SSID' to $CONN_FILE..."

    cat > "$CONN_FILE" <<EOF
[connection]
id=$SSID
type=wifi
autoconnect=true

[wifi]
mode=infrastructure
ssid=$SSID

[wifi-security]
key-mgmt=wpa-psk
psk=$PASSWORD

[ipv4]
method=auto

[ipv6]
method=auto
EOF

    chmod 600 "$CONN_FILE"

    success "Wrote wifi connection profile to $CONN_FILE (will connect on next boot)"
}

case "$MODE" in
    ssh)
        update_via_ssh
        ;;
    offline)
        update_offline
        ;;
    *)
        usage
        error "Unknown --mode '$MODE' (expected ssh or offline)"
        ;;
esac
