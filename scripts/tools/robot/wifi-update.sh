#!/bin/bash
# wifi-update.sh — update a robot's wifi connection in one of two modes:
#
#   ssh     Connect to a robot over ethernet (so it stays reachable even if
#           the new wifi credentials turn out to be wrong) and use nmcli to
#           create/replace a NetworkManager wifi connection profile, then
#           bring it up.
#   offline Arm a one-time "run on next boot" hook on a mounted bootfs (the
#           FAT32 boot/firmware partition — the one macOS/Windows/Linux can
#           all mount directly, unlike the ext4 rootfs) partition of a
#           Raspberry Pi OS Bookworm+ SD card/USB boot disk, so the device
#           writes its own NetworkManager wifi connection profile and joins
#           the given network the next time it boots. Works the same whether
#           the card is a pristine unflashed image or one that's already been
#           running in a robot for a long time — this does NOT apply
#           immediately, only on next boot.
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
  --mount <path>         Mount path of the bootfs (boot/firmware, FAT32) partition of the SD
                         card/USB disk (offline mode, or MECHA10_WIFI_MOUNT)
  --ssid <ssid>          Wifi network name (or MECHA10_WIFI_SSID)
  --password <password>  Wifi password (or MECHA10_WIFI_PASSWORD)
  --env-file <path>      .env-style file to source first (or MECHA10_WIFI_ENV_FILE)
  -h, --help             Show this help

ssh mode runs over ethernet, so the robot stays reachable even if the new
wifi credentials turn out to be wrong. It applies immediately.

offline mode expects <path> to be the already-mounted bootfs (boot/firmware,
FAT32) partition of a Raspberry Pi OS Bookworm+ SD card/USB boot disk — the
one macOS, Windows, and Linux can all mount directly (the ext4 rootfs cannot
be mounted on macOS). It arms a one-time "run on next boot" hook
(firstrun.sh + a cmdline.txt systemd.run= entry, the same mechanism
Raspberry Pi Imager itself uses) that writes the NetworkManager wifi
connection profile on the device itself. It does NOT apply immediately —
only the next time the device boots. This works the same whether the card is
a pristine unflashed image or one that's already been running in a robot for
a long time. Eject the media, put it back in the robot, and power-cycle it;
the hook and script remove themselves automatically once applied.
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

    CMDLINE="$MOUNT_PATH/cmdline.txt"
    [ -f "$CMDLINE" ] || error "'$CMDLINE' not found — is '$MOUNT_PATH' the mounted bootfs (boot/firmware, FAT32) partition of a Raspberry Pi OS Bookworm+ SD card/USB disk?"

    FIRSTRUN="$MOUNT_PATH/firstrun.sh"
    [ -e "$FIRSTRUN" ] && error "'$FIRSTRUN' already exists — a first-run job may already be pending. Resolve or remove it first, then re-run this tool."

    BACKUP="$CMDLINE.wifi-update.bak"
    if [ -e "$BACKUP" ]; then
        info "Backup '$BACKUP' already exists — leaving it as-is (not overwriting)."
    else
        info "Backing up $CMDLINE to $BACKUP..."
        cp "$CMDLINE" "$BACKUP"
    fi

    if grep -q 'systemd\.run=' "$CMDLINE"; then
        error "'$CMDLINE' already contains a 'systemd.run=' hook — something else may already have a first-run job queued. Resolve it manually before re-running this tool."
    fi

    info "Writing first-run wifi setup script to $FIRSTRUN..."

    cat > "$FIRSTRUN" <<EOF
#!/bin/bash
set +e

CONN_DIR="/etc/NetworkManager/system-connections"
CONN_FILE="\$CONN_DIR/${SSID}.nmconnection"
mkdir -p "\$CONN_DIR"

# Remove any existing profile for this SSID before writing the new one
rm -f "\$CONN_FILE"

cat > "\$CONN_FILE" <<'NMCONN'
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
NMCONN

chmod 600 "\$CONN_FILE"

nmcli connection reload 2>/dev/null || true
nmcli connection up "$SSID" 2>/dev/null || true

# Self-cleanup: remove this script and restore cmdline.txt to its pre-hook state
rm -f /boot/firmware/firstrun.sh
if [ -f /boot/firmware/cmdline.txt.wifi-update.bak ]; then
    mv /boot/firmware/cmdline.txt.wifi-update.bak /boot/firmware/cmdline.txt
fi

exit 0
EOF

    chmod +x "$FIRSTRUN"

    info "Appending one-time boot hook to $CMDLINE..."
    printf '%s' " systemd.run=/boot/firmware/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target" >> "$CMDLINE"

    success "Armed first-run wifi setup for '$SSID' on $MOUNT_PATH."
    info "This takes effect on the device's NEXT BOOT, not immediately."
    info "Eject the media, put it back in the robot, and power-cycle it."
    info "The hook and script remove themselves automatically once applied."
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
