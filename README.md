# Mecha10 User Tools

[![CI](https://github.com/mecha-industries/user-tools/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/mecha-industries/user-tools/actions/workflows/ci.yml) ![License](https://img.shields.io/badge/license-Unknown-blue) ![Last commit](https://img.shields.io/github/last-commit/mecha-industries/user-tools) ![Top language](https://img.shields.io/github/languages/top/mecha-industries/user-tools)

Public distribution repository for Mecha10 CLI and Launcher binaries.

## Scripts at a Glance

| Script | What it does | Details |
|--------|---------------|---------|
| `scripts/install.sh` | Installs the Mecha10 CLI (served via the curl one-liner) | [CLI Installation](#cli-installation) |
| `scripts/install-launcher.sh` | Installs the Mecha10 Launcher on a robot | [Launcher Installation](#launcher-installation-linux) |
| `scripts/tools/robot/gpio-test.sh` | Cycles GPIO motor-control pins for wiring/driver-board debugging | [Robot Setup & Diagnostic Tools](#robot-setup--diagnostic-tools) |
| `scripts/tools/robot/i2c-test.sh` | Scans an I2C bus and reports detected devices, with hints for known mecha10 sensors | [Robot Setup & Diagnostic Tools](#robot-setup--diagnostic-tools) |
| `scripts/tools/robot/servo_test.py` | Sweeps a servo through min/mid/max pulse widths over hardware PWM | [Robot Setup & Diagnostic Tools](#robot-setup--diagnostic-tools) |
| `scripts/tools/robot/imu-test.py` | Reads live accelerometer/gyro/temperature data from an MPU6050 IMU over I2C | [Robot Setup & Diagnostic Tools](#robot-setup--diagnostic-tools) |
| `scripts/tools/robot/wifi-update.sh` | Updates a robot's wifi, live over SSH or via a first-boot bootfs job | [Robot Setup & Diagnostic Tools](#robot-setup--diagnostic-tools) |
| `scripts/tools/robot/first-boot.sh` | Full first-time provisioning of a fresh Raspberry Pi OS install for a robot | [Robot Setup & Diagnostic Tools](#robot-setup--diagnostic-tools) |

Everything under `scripts/ci/` (CI failure-ticket helper and its shared library code) and
`scripts/lib/` (shared library code sourced by the scripts above) is internal plumbing — not
meant to be run directly by an end user, and not covered below.

## Connecting to a Robot

Copy `.env.template` to `.env` and fill in your robot's host/user/password (and the wifi
SSID/password if you're using `wifi-update.sh`):

```bash
cp .env.template .env
# edit .env with your robot's details
```

Then pass it via `--env-file .env` to any script that supports it (`install-launcher.sh
--mode ssh`, `wifi-update.sh --mode ssh`) instead of repeating flags on the command line.

## CLI Installation

Install the Mecha10 CLI on your development machine:

```bash
curl -fsSL https://mecha.industries/api/install.sh | sh
```

### Options

```bash
# Install specific version
MECHA10_VERSION=0.2.4 curl -fsSL ... | sh

# Install to custom directory
MECHA10_INSTALL_DIR=/usr/local/bin curl -fsSL ... | sh

# Use a different API endpoint
MECHA10_API_URL=https://mecha.industries/api curl -fsSL ... | sh
```

### Supported Platforms

| OS | Architecture | Status |
|----|--------------|--------|
| macOS | Apple Silicon (arm64) | Supported |
| macOS | Intel (x86_64) | Supported |
| Linux | x86_64 | Supported |
| Linux | aarch64 | Supported |

## Launcher Installation (Linux)

Install the Mecha10 Launcher on your robot/edge device:

```bash
curl -fsSL https://mecha.industries/api/install-launcher.sh | sh
```

### Options

```bash
# Install specific version
MECHA10_VERSION=0.2.4 curl -fsSL ... | sh

# Skip systemd service setup
MECHA10_NO_SERVICE=1 curl -fsSL ... | sh

# Use a different API endpoint
MECHA10_API_URL=https://mecha.industries/api curl -fsSL ... | sh
```

### Remote (SSH) Install

Install over SSH using password auth, instead of running the curl one-liner directly on the
robot. Requires `sshpass` on the machine running the script (`brew install sshpass` on macOS,
`apt install sshpass` on Linux):

```bash
./scripts/install-launcher.sh --mode ssh --host 192.168.1.50 --ssh-password secret123

# Or using .env (see "Connecting to a Robot" above)
./scripts/install-launcher.sh --mode ssh --env-file .env
```

### Launcher Setup

After installation:

1. **Login** directly on the robot:
   ```bash
   mecha10 auth login
   ```
   This uses a device-code flow, so it works headlessly on the robot itself — no dev
   machine or `scp` required. Follow the printed URL/code to authorize from any browser.

2. **Configure** on the robot (`~/.mecha10/launcher/config.json`):
   ```json
   {
     "robot_project": {
       "name": "your-project-name",
       "install_dir": "~/mecha10/robots"
     },
     "platform_url": "https://mecha.industries",
     "robot_id": "your-robot-id",
     "auto_update": true
   }
   ```

3. **Start** the launcher:
   ```bash
   systemctl --user start mecha10-launcher
   ```

### Supported Platforms

| OS | Architecture | Status |
|----|--------------|--------|
| Linux | x86_64 | Supported |
| Linux | aarch64 (Pi 5) | Supported |

## What Gets Downloaded

### CLI

Downloads via the mecha10 downloads API (`${MECHA10_API_URL}/downloads/cli?os=...&arch=...`),
which proxies internal storage — you don't need direct access to that storage:
- the `mecha10` CLI binary archive for your OS/architecture

When you run `mecha10 sim` commands, additional assets are downloaded the same way:
- `mecha10-simulation.tar.gz` - Godot project, robot models, environments

### Launcher

Downloads via the mecha10 downloads API (`${MECHA10_API_URL}/downloads/launcher?arch=...`),
which proxies internal storage — you don't need direct access to that storage:
- the `mecha10-launcher` binary archive for your architecture

## Docker Images

Users can also access public Docker images:

```bash
# Remote node runner (for AI/ML nodes)
docker pull ghcr.io/mecha-industries/mecha10-remote:latest

# Or via CLI
mecha10 remote up
```

## Robot Setup & Diagnostic Tools

`scripts/tools/robot/` holds manual hardware setup/diagnostic tools for mecha10 robots. These
are run directly on, or against, the robot's Raspberry Pi — they're unrelated to the CLI/
launcher binary distribution pipeline covered above.

- `gpio-test.sh` — exercises GPIO pins used for motor control (individually and in common
  motor-driver combos), for debugging wiring and driver boards.

  ```bash
  # Run as-is — it takes no arguments
  ./scripts/tools/robot/gpio-test.sh
  ```

  Needs real GPIO hardware access (`gpiodetect`/`gpioget`/`gpioset` against the robot's GPIO
  chip) — run as a user with access to `/dev/gpiochip*`, typically via `sudo` or `gpio`-group
  membership. It auto-detects the right chip (`gpiochip0` on a Pi 4, `gpiochip4` on a Pi 5),
  then cycles through: all pins HIGH, all pins LOW, each pin individually toggled HIGH/LOW
  against the opposite baseline, named combos for boards it already knows about (Viam Rover 2,
  active-low; L298N, active-high), and a few adjacent-pin pairs — printing each test label to
  the console before/after it runs, 2 seconds per step.

- `i2c-test.sh` — scans an I2C bus and reports what's detected, with hints for a few
  addresses mecha10 robots actually use.

  ```bash
  # Default: scans bus 1 (/dev/i2c-1)
  ./scripts/tools/robot/i2c-test.sh

  # Scan a different bus
  ./scripts/tools/robot/i2c-test.sh --bus 0
  ```

  Needs `i2c-tools` installed (already installed by `first-boot.sh`) — errors out clearly
  with an install instruction (`sudo apt install i2c-tools`) if missing. Runs `i2cdetect -y
  <bus>` and prints its raw table output, then a short human-readable summary below it:
  `0x68`/`0x69` as a likely MPU6050 IMU (see `imu-test.py`), `0x76`/`0x77` as a likely
  BMP280/BME280 pressure/temperature sensor, `0x3C`/`0x3D` as a likely SSD1306 OLED display,
  and any other detected address listed plainly with no guessed hint. These hints are purely
  informative, not authoritative. If nothing is detected, it suggests checking wiring/pull-up
  resistors and confirming I2C is actually enabled (`sudo raspi-config nonint get_i2c`).

- `servo_test.py` — sweeps a servo through min/mid/max pulse widths over the kernel's
  hardware PWM sysfs interface.

  ```bash
  # Default: channels 0:0 and 0:1 (GPIO12/13 under the pwm-2chan overlay), mid -> max -> min -> mid
  ./scripts/tools/robot/servo_test.py

  # Override channels and narrow the pulse range
  ./scripts/tools/robot/servo_test.py --channels 0:0 --min-us 900 --max-us 2100 --duration 3
  ```

  Flags: `--channels CHIP:CHANNEL [...]` (default `0:0 0:1`), `--min-us` (default `600`),
  `--max-us` (default `2400`), `--duration` in seconds (default `2.0`), `--tick` step interval
  (default `0.02`), `--settle` pause at each endpoint (default `0.3`). Requires the PWM
  channel's device-tree overlay to already be enabled (e.g. `dtoverlay=pwm-2chan` in
  `/boot/firmware/config.txt` on a Pi) and each `pwm<M>` channel to be unexported before
  running.

- `imu-test.py` — reads live accelerometer/gyro/temperature data from an MPU6050 IMU over I2C.

  ```bash
  # Default: bus 1 (/dev/i2c-1), address 0x68, 10 samples/sec for 5 seconds
  ./scripts/tools/robot/imu-test.py

  # Run until Ctrl+C instead of a fixed duration
  ./scripts/tools/robot/imu-test.py --duration 0
  ```

  Flags: `--bus` (default `1`, meaning `/dev/i2c-1`), `--address` (default `0x68`, accepts hex
  or decimal), `--rate` samples per second to print (default `10`), `--duration` in seconds,
  `0` meaning run until Ctrl+C (default `5`). Mirrors mecha10-nodes' real `imu` crate hardware
  defaults (bus `/dev/i2c-1`, address `0x68`, +/-250 deg/s gyro scale, +/-2g accel scale).
  Requires the `smbus2` package (`pip install smbus2` or the `python3-smbus2`/`python3-smbus`
  apt package). If the device isn't detected, run `i2c-test.sh` first to confirm detection and
  the correct bus/address.

- `wifi-update.sh` — updates a robot's wifi connection, in one of two modes:

  ```bash
  # Mode A: update wifi on a live robot reachable over ethernet (SSH, password auth)
  ./scripts/tools/robot/wifi-update.sh --mode ssh --host 192.168.1.50 --ssh-password secret123 \
      --ssid MyNetwork --password secret123

  # Or using .env (see "Connecting to a Robot" above)
  ./scripts/tools/robot/wifi-update.sh --mode ssh --env-file .env --ssid MyNetwork --password secret123

  # Mode B: arm a first-boot wifi setup job on the mounted bootfs (boot/firmware, FAT32)
  # partition of an SD card/USB disk
  ./scripts/tools/robot/wifi-update.sh --mode offline --mount /mnt/bootfs --ssid MyNetwork --password secret123
  ```

  Mode A connects over SSH using password auth (via `sshpass` — install it first, e.g.
  `brew install sshpass` on macOS, `apt install sshpass` on Linux) over ethernet, so the robot
  stays reachable even if the new wifi credentials are wrong, and applies immediately. Note
  `--ssh-password` (the robot's SSH login password, `MECHA10_ROBOT_PASSWORD`) is distinct from
  `--password` (the wifi network password being set, `MECHA10_WIFI_PASSWORD`). Mode B arms a
  one-time "run on next boot" hook (the same mechanism Raspberry Pi Imager itself uses) on the
  mounted bootfs — the FAT32 boot/firmware partition that macOS, Windows, and Linux can all
  mount directly, unlike the ext4 rootfs — so the device writes its own NetworkManager
  connection profile and joins the network the next time it boots. It does NOT apply
  immediately, and works the same whether the card is a pristine unflashed image or one that's
  already been running in a robot for a long time. Both modes support `MECHA10_ROBOT_*`/
  `MECHA10_WIFI_*`-prefixed env vars (and an optional `--env-file`/`MECHA10_WIFI_ENV_FILE`) as
  an alternative to CLI flags — see `--help` for details.

- `first-boot.sh` — full first-time provisioning of a fresh Raspberry Pi OS Lite (Bookworm or
  later) install: system update, hostname, disable bluetooth, reduce disk writes for SD/USB
  card longevity, install camera/GPIO dev tools, enable I2C/SPI, configure wifi (+ optional
  static IP) via `nmcli`, Pi 5 EEPROM boot-order/USB-boot config, minor performance tuning, a
  health-check summary, and `mecha10-launcher` install.

  ```bash
  # Typical flow: SSH in over ethernet before wifi is configured (Pi's default mDNS hostname)
  scp scripts/tools/robot/first-boot.sh .env pi@raspberrypi.local:~/
  ssh pi@raspberrypi.local
  sudo bash ~/first-boot.sh my-robot-01 --env ~/.env
  sudo reboot
  ```

  Requires `MECHA10_WIFI_SSID` and `MECHA10_WIFI_PASSWORD` (errors out clearly if missing).
  Optional: `MECHA10_ROBOT_STATIC_IP` (+ `MECHA10_ROBOT_GATEWAY`, `MECHA10_ROBOT_DNS`) for a
  static wifi IP instead of DHCP, and `MECHA10_ROBOT_BOOT_ORDER`,
  `MECHA10_ROBOT_USB_MSD_STARTUP_DELAY`, `MECHA10_ROBOT_USB_MSD_DISCOVER_TIMEOUT` for Pi 5 EEPROM
  tuning. Takes `--env <file>` (or `ENV_FILE`) to source these from a `.env`-style file instead
  of exporting them by hand. Run as root on the Pi itself — standalone, no other files in this
  repo required.

## Maintainers

Build and publish scripts are in the [mecha10 monorepo](https://github.com/mecha-industries/mecha10).

See [`scripts/README.md`](https://github.com/mecha-industries/mecha10/blob/main/scripts/README.md) in that repository for release instructions.
