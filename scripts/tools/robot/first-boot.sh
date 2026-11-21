#!/bin/bash
# first-boot.sh — full first-time provisioning for a fresh Raspberry Pi OS
# Lite (Bookworm or later) install on a mecha10 robot's Raspberry Pi.
#
# Run as root, directly on the Pi:
#   sudo bash first-boot.sh <hostname> [--env FILE]
#
# Steps (each logged as it runs):
#   1.  System package update (apt update && apt upgrade -y)
#   2.  Set hostname (hostnamectl set-hostname <hostname>)
#   3.  Disable bluetooth (headless robot, not needed)
#   4.  Reduce disk writes for SD/USB card longevity (journald to RAM,
#       disable write-heavy timers, truncate noisy logs)
#   5.  Install camera stack (rpicam-apps, libcamera-tools) and GPIO/hardware
#       dev tools (python3-pip, python3-venv, python3-lgpio, i2c-tools)
#   6.  Enable I2C and SPI via raspi-config
#   7.  Configure wifi via nmcli (+ optional static IP), ethernet stays DHCP
#   8.  Pi 5 EEPROM bootloader config (BOOT_ORDER, USB MSD timing)
#   9.  Minor performance tuning (swappiness, hardware watchdog)
#   10. Print a final health-check summary
#   11. Install mecha10-launcher
#   12. Recommend a reboot
#
# Required env vars (error out clearly if missing):
#   MECHA10_WIFI_SSID                      wifi network name
#   MECHA10_WIFI_PASSWORD                  wifi password
#
# Optional env vars (defaults noted):
#   MECHA10_ROBOT_STATIC_IP                 static IP (CIDR, e.g. 192.168.1.50/24) for
#                                           wifi — unset means DHCP
#   MECHA10_ROBOT_GATEWAY                   gateway for the static IP (required if
#                                           MECHA10_ROBOT_STATIC_IP is set)
#   MECHA10_ROBOT_DNS                       DNS server(s) for the static IP, space/comma
#                                           separated (default: 1.1.1.1 8.8.8.8)
#   MECHA10_ROBOT_BOOT_ORDER                Pi 5 EEPROM BOOT_ORDER (default: 0xf14 — try
#                                           USB then SD, then retry)
#   MECHA10_ROBOT_USB_MSD_STARTUP_DELAY     Pi 5 EEPROM USB_MSD_STARTUP_DELAY, ms
#                                           (default: 10000)
#   MECHA10_ROBOT_USB_MSD_DISCOVER_TIMEOUT  Pi 5 EEPROM USB_MSD_DISCOVER_TIMEOUT, ms
#                                           (default: 30000)
#
# --env FILE / ENV_FILE sources a .env-style file providing any of the above
# (matches this repo's other scripts' convention).

set -e

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
if [ -f "$script_dir/../../lib/install-common.sh" ]; then
    # shellcheck source=scripts/lib/install-common.sh
    . "$script_dir/../../lib/install-common.sh"
else
    # This script is designed to also work standalone (copied onto a device
    # without the rest of the repo present), so fall back to inline helpers
    # if the shared lib isn't available alongside it.
    info() { printf "\033[0;34m==>\033[0m %s\n" "$1"; }
    success() { printf "\033[0;32m==>\033[0m %s\n" "$1"; }
    warn() { printf "\033[1;33mWarning:\033[0m %s\n" "$1" >&2; }
    error() { printf "\033[0;31mError:\033[0m %s\n" "$1" >&2; exit 1; }
fi

usage() {
    cat <<EOF
Usage:
  sudo bash first-boot.sh <hostname> [--env FILE]

Arguments:
  <hostname>       Hostname to set on this Pi

Options:
  --env <file>     .env-style file to source first (or ENV_FILE)
  -h, --help       Show this help

Required env vars (error out clearly if missing):
  MECHA10_WIFI_SSID                      wifi network name
  MECHA10_WIFI_PASSWORD                  wifi password

Optional env vars:
  MECHA10_ROBOT_STATIC_IP                 static IP (CIDR) for wifi, default: DHCP
  MECHA10_ROBOT_GATEWAY                   gateway for the static IP (required if set)
  MECHA10_ROBOT_DNS                       DNS server(s), default: 1.1.1.1 8.8.8.8
  MECHA10_ROBOT_BOOT_ORDER                Pi 5 EEPROM BOOT_ORDER, default: 0xf14
  MECHA10_ROBOT_USB_MSD_STARTUP_DELAY     Pi 5 EEPROM USB_MSD_STARTUP_DELAY (ms), default: 10000
  MECHA10_ROBOT_USB_MSD_DISCOVER_TIMEOUT  Pi 5 EEPROM USB_MSD_DISCOVER_TIMEOUT (ms), default: 30000
EOF
}

if [ "$(id -u)" -ne 0 ]; then
    error "This script must be run as root (sudo bash first-boot.sh <hostname> [--env FILE])"
fi

HOSTNAME_ARG=""
ENV_FILE="${ENV_FILE:-}"

while [ $# -gt 0 ]; do
    case "$1" in
        --env)
            ENV_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            usage
            error "Unknown argument: $1"
            ;;
        *)
            if [ -n "$HOSTNAME_ARG" ]; then
                usage
                error "Unexpected extra argument: $1"
            fi
            HOSTNAME_ARG="$1"
            shift
            ;;
    esac
done

[ -n "$HOSTNAME_ARG" ] || { usage; error "<hostname> is required"; }

if [ -n "$ENV_FILE" ]; then
    [ -f "$ENV_FILE" ] || error "--env file '$ENV_FILE' not found"
    # shellcheck disable=SC1090
    . "$ENV_FILE"
fi

[ -n "${MECHA10_WIFI_SSID:-}" ] || error "MECHA10_WIFI_SSID is required (set it or pass --env FILE)"
[ -n "${MECHA10_WIFI_PASSWORD:-}" ] || error "MECHA10_WIFI_PASSWORD is required (set it or pass --env FILE)"

BOOT_ORDER="${MECHA10_ROBOT_BOOT_ORDER:-0xf14}"
USB_MSD_STARTUP_DELAY="${MECHA10_ROBOT_USB_MSD_STARTUP_DELAY:-10000}"
USB_MSD_DISCOVER_TIMEOUT="${MECHA10_ROBOT_USB_MSD_DISCOVER_TIMEOUT:-30000}"
DNS_SERVERS="${MECHA10_ROBOT_DNS:-1.1.1.1 8.8.8.8}"

step_update_system() {
    info "[1/12] Updating system packages..."
    DEBIAN_FRONTEND=noninteractive apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    success "System packages updated"
}

step_set_hostname() {
    info "[2/12] Setting hostname to '$HOSTNAME_ARG'..."
    hostnamectl set-hostname "$HOSTNAME_ARG"
    if grep -q '^127\.0\.1\.1' /etc/hosts; then
        sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$HOSTNAME_ARG/" /etc/hosts
    else
        printf '127.0.1.1\t%s\n' "$HOSTNAME_ARG" >> /etc/hosts
    fi
    success "Hostname set to '$HOSTNAME_ARG'"
}

step_disable_bluetooth() {
    info "[3/12] Disabling bluetooth..."
    if systemctl list-unit-files | grep -q '^bluetooth\.service'; then
        systemctl disable --now bluetooth.service 2>/dev/null || true
        success "Bluetooth disabled"
    else
        info "No bluetooth service present — skipping"
    fi
    if command -v raspi-config >/dev/null 2>&1 && raspi-config nonint get_bluetooth >/dev/null 2>&1; then
        raspi-config nonint do_bluetooth 1 || true
    fi
}

step_reduce_disk_writes() {
    info "[4/12] Reducing disk writes for SD/USB card longevity..."

    mkdir -p /etc/systemd/journald.conf.d
    cat > /etc/systemd/journald.conf.d/volatile.conf <<'EOF'
[Journal]
Storage=volatile
RuntimeMaxUse=16M
EOF
    systemctl restart systemd-journald 2>/dev/null || true

    for timer in apt-daily.timer apt-daily-upgrade.timer man-db.timer dpkg-db-backup.timer e2scrub_all.timer logrotate.timer; do
        if systemctl list-unit-files | grep -q "^${timer}"; then
            systemctl disable --now "$timer" 2>/dev/null || true
            info "Disabled $timer"
        fi
    done

    for log in /var/log/syslog /var/log/daemon.log /var/log/auth.log /var/log/kern.log; do
        [ -f "$log" ] && : > "$log"
    done

    success "Disk-write reduction applied"
}

step_install_hardware_tools() {
    info "[5/12] Installing camera and GPIO/hardware dev tools..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        rpicam-apps \
        libcamera-tools \
        python3-pip \
        python3-venv \
        python3-lgpio \
        i2c-tools
    success "Camera and GPIO/hardware dev tools installed"
}

step_enable_i2c_spi() {
    info "[6/12] Enabling I2C and SPI..."
    if command -v raspi-config >/dev/null 2>&1; then
        raspi-config nonint do_i2c 0
        raspi-config nonint do_spi 0
        success "I2C and SPI enabled"
    else
        warn "raspi-config not found — skipping I2C/SPI enablement"
    fi
}

step_configure_wifi() {
    info "[7/12] Configuring wifi..."

    if ! command -v nmcli >/dev/null 2>&1; then
        warn "nmcli not found — skipping wifi configuration"
        return
    fi

    CONN_NAME="$MECHA10_WIFI_SSID"

    if nmcli -t -f NAME connection show | grep -Fxq "$CONN_NAME"; then
        nmcli connection delete "$CONN_NAME"
    fi

    nmcli connection add type wifi con-name "$CONN_NAME" ifname wlan0 ssid "$MECHA10_WIFI_SSID" \
        wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$MECHA10_WIFI_PASSWORD" connection.autoconnect yes

    if [ -n "${MECHA10_ROBOT_STATIC_IP:-}" ]; then
        [ -n "${MECHA10_ROBOT_GATEWAY:-}" ] || error "MECHA10_ROBOT_GATEWAY is required when MECHA10_ROBOT_STATIC_IP is set"
        info "Configuring static IP $MECHA10_ROBOT_STATIC_IP on wifi (gateway: $MECHA10_ROBOT_GATEWAY)..."
        nmcli connection modify "$CONN_NAME" \
            ipv4.method manual \
            ipv4.addresses "$MECHA10_ROBOT_STATIC_IP" \
            ipv4.gateway "$MECHA10_ROBOT_GATEWAY" \
            ipv4.dns "$(printf '%s' "$DNS_SERVERS" | tr ',' ' ')"
    else
        info "No MECHA10_ROBOT_STATIC_IP set — wifi will use DHCP"
    fi

    nmcli connection up "$CONN_NAME" || warn "Could not bring up wifi connection now — it will connect on next boot"

    info "Ethernet left untouched on DHCP (recovery path)"
    success "Wifi configured"
}

step_configure_eeprom() {
    info "[8/12] Checking Pi 5 EEPROM bootloader config..."

    if ! command -v rpi-eeprom-config >/dev/null 2>&1; then
        info "rpi-eeprom-config not found (not a Pi 5, or tools not installed) — skipping"
        return
    fi

    CURRENT_CONFIG="$(rpi-eeprom-config 2>/dev/null || true)"
    DESIRED_CONFIG=$(cat <<EOF
BOOT_ORDER=$BOOT_ORDER
USB_MSD_STARTUP_DELAY=$USB_MSD_STARTUP_DELAY
USB_MSD_DISCOVER_TIMEOUT=$USB_MSD_DISCOVER_TIMEOUT
EOF
)

    NEEDS_UPDATE=0
    for line in "BOOT_ORDER=$BOOT_ORDER" "USB_MSD_STARTUP_DELAY=$USB_MSD_STARTUP_DELAY" "USB_MSD_DISCOVER_TIMEOUT=$USB_MSD_DISCOVER_TIMEOUT"; do
        if ! printf '%s\n' "$CURRENT_CONFIG" | grep -Fxq "$line"; then
            NEEDS_UPDATE=1
        fi
    done

    if [ "$NEEDS_UPDATE" -eq 0 ]; then
        info "EEPROM config already up to date — skipping"
        return
    fi

    TMP_CONFIG="$(mktemp)"
    trap 'rm -f "$TMP_CONFIG"' RETURN
    printf '%s\n' "$CURRENT_CONFIG" | grep -vE '^(BOOT_ORDER|USB_MSD_STARTUP_DELAY|USB_MSD_DISCOVER_TIMEOUT)=' > "$TMP_CONFIG" || true
    printf '%s\n' "$DESIRED_CONFIG" >> "$TMP_CONFIG"

    rpi-eeprom-config --apply "$TMP_CONFIG"
    success "EEPROM config updated (BOOT_ORDER=$BOOT_ORDER, USB_MSD_STARTUP_DELAY=$USB_MSD_STARTUP_DELAY, USB_MSD_DISCOVER_TIMEOUT=$USB_MSD_DISCOVER_TIMEOUT) — takes effect next boot"
}

step_performance_tuning() {
    info "[9/12] Applying minor performance tuning..."

    mkdir -p /etc/sysctl.d
    cat > /etc/sysctl.d/99-mecha10-swappiness.conf <<'EOF'
vm.swappiness=10
EOF
    sysctl -p /etc/sysctl.d/99-mecha10-swappiness.conf >/dev/null 2>&1 || true

    mkdir -p /etc/systemd/system.conf.d
    if ! grep -rq '^RuntimeWatchdogSec=' /etc/systemd/system.conf /etc/systemd/system.conf.d/*.conf 2>/dev/null; then
        cat > /etc/systemd/system.conf.d/watchdog.conf <<'EOF'
[Manager]
RuntimeWatchdogSec=10
EOF
        info "Hardware watchdog enabled (RuntimeWatchdogSec=10)"
    else
        info "Hardware watchdog already configured — skipping"
    fi

    success "Performance tuning applied"
}

step_health_check() {
    info "[10/12] Health check summary:"
    echo "  Hostname:        $(hostnamectl --static 2>/dev/null || hostname)"
    if command -v vcgencmd >/dev/null 2>&1; then
        echo "  Temperature:     $(vcgencmd measure_temp 2>/dev/null || echo 'unavailable')"
        echo "  Throttled:       $(vcgencmd get_throttled 2>/dev/null || echo 'unavailable')"
    else
        echo "  Temperature:     vcgencmd unavailable"
    fi
    if command -v rpicam-hello >/dev/null 2>&1; then
        echo "  Cameras:"
        rpicam-hello --list-cameras 2>/dev/null | sed 's/^/    /' || echo "    none detected"
    else
        echo "  Cameras:         rpicam-hello unavailable"
    fi
    echo "  Free memory:"
    free -h | sed 's/^/    /'
    echo "  Free disk:"
    df -h / | sed 's/^/    /'
    if command -v i2cdetect >/dev/null 2>&1; then
        I2C_COUNT=$(i2cdetect -l 2>/dev/null | wc -l | tr -d ' ')
        echo "  I2C buses:       $I2C_COUNT"
    else
        echo "  I2C buses:       i2cdetect unavailable"
    fi
}

step_install_launcher() {
    info "[11/12] Installing mecha10-launcher..."
    curl -fsSL https://mecha.industries/api/install-launcher.sh | sh
    success "mecha10-launcher installed"
}

main() {
    step_update_system
    step_set_hostname
    step_disable_bluetooth
    step_reduce_disk_writes
    step_install_hardware_tools
    step_enable_i2c_spi
    step_configure_wifi
    step_configure_eeprom
    step_performance_tuning
    step_health_check
    step_install_launcher

    info "[12/12] First-boot provisioning complete."
    success "Reboot recommended to apply all changes: sudo reboot"
}

main
