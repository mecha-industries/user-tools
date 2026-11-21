#!/bin/bash
# I2C Bus Scan Test
#
# Hardware diagnostic utility for scanning an I2C bus and reporting what's
# detected. Run manually on a robot's Raspberry Pi — not part of the CLI/
# launcher distribution pipeline the other scripts in this directory serve.
#
# Usage:
#   ./scripts/tools/robot/i2c-test.sh [--bus N]
#
#   --bus N     I2C bus number to scan (default: 1, i.e. /dev/i2c-1 —
#               matches this repo's other I2C scripts, e.g. imu-test.py)
#   -h, --help  Show this help and exit
#
# Requires i2c-tools (installed by first-boot.sh) for i2cdetect. Errors out
# clearly with an install instruction if it's missing.
#
# Runs `i2cdetect -y <bus>`, prints its raw table output as-is, then parses
# the detected addresses and prints a short human-readable summary with
# hints for a few addresses mecha10 robots actually use:
#   - 0x68/0x69 -> likely an MPU6050 IMU (see imu-test.py)
#   - 0x76/0x77 -> likely a BMP280/BME280 pressure/temperature sensor
#   - 0x3C/0x3D -> likely an SSD1306 OLED display
#   - anything else detected is listed plainly with no guessed hint
#
# If nothing is detected, suggests checking wiring/pull-up resistors and
# that I2C is actually enabled (mirrors how first-boot.sh enables I2C).

set -euo pipefail

BUS=1

usage() {
    cat <<EOF
Usage: $(basename "$0") [--bus N]

  --bus N     I2C bus number to scan (default: 1, i.e. /dev/i2c-1)
  -h, --help  Show this help and exit
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --bus)
            BUS="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if ! command -v i2cdetect >/dev/null 2>&1; then
    echo "ERROR: i2cdetect not found. Install the i2c-tools package:" >&2
    echo "  sudo apt install i2c-tools" >&2
    exit 1
fi

echo "=== I2C Bus ${BUS} Scan (/dev/i2c-${BUS}) ==="
SCAN_OUTPUT="$(i2cdetect -y "$BUS")"
echo "$SCAN_OUTPUT"
echo ""

ADDRESSES="$(echo "$SCAN_OUTPUT" | tail -n +2 | awk '{ $1=""; print }' | grep -oE '[0-9a-f]{2}' | sort -u)"

echo "=== Summary ==="
if [ -z "$ADDRESSES" ]; then
    echo "No devices detected on bus ${BUS}."
    echo "Check wiring/pull-up resistors, and confirm I2C is actually enabled:"
    echo "  sudo raspi-config nonint get_i2c   # 0 = enabled, 1 = disabled"
    echo "(first-boot.sh enables I2C via: sudo raspi-config nonint do_i2c 0)"
    exit 0
fi

for addr in $ADDRESSES; do
    case "$addr" in
        68|69)
            echo "0x${addr} - likely an MPU6050 IMU (see imu-test.py)"
            ;;
        76|77)
            echo "0x${addr} - likely a BMP280/BME280 pressure/temperature sensor"
            ;;
        3c|3d)
            echo "0x${addr} - likely an SSD1306 OLED display"
            ;;
        *)
            echo "0x${addr} - detected (no known hint)"
            ;;
    esac
done
