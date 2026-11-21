# Mecha10 User Tools

[![CI](https://github.com/mecha-industries/user-tools/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/mecha-industries/user-tools/actions/workflows/ci.yml) ![License](https://img.shields.io/badge/license-Unknown-blue) ![Last commit](https://img.shields.io/github/last-commit/mecha-industries/user-tools) ![Top language](https://img.shields.io/github/languages/top/mecha-industries/user-tools)

Public distribution repository for Mecha10 CLI and Launcher binaries.

## Scripts at a Glance

| Script | What it does | Details |
|--------|---------------|---------|
| `scripts/install.sh` | Installs the Mecha10 CLI (served via the curl one-liner) | [CLI Installation](#cli-installation) |
| `scripts/install-launcher.sh` | Installs the Mecha10 Launcher on a robot | [Launcher Installation](#launcher-installation-linux) |
| `scripts/tools/robot/gpio-test.sh` | Cycles GPIO motor-control pins for wiring/driver-board debugging | [Robot Setup & Diagnostic Tools](#robot-setup--diagnostic-tools) |
| `scripts/tools/robot/servo_test.py` | Sweeps a servo through min/mid/max pulse widths over hardware PWM | [Robot Setup & Diagnostic Tools](#robot-setup--diagnostic-tools) |
| `scripts/tools/robot/wifi-update.sh` | Updates a robot's wifi, live over SSH or via a first-boot bootfs job | [Robot Setup & Diagnostic Tools](#robot-setup--diagnostic-tools) |

`scripts/file-ci-failure-ticket.sh` and everything under `scripts/lib/` are internal plumbing
(CI failure-ticket helper and shared library code sourced by the scripts above) — not meant to
be run directly by an end user, and not covered below.

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

- `wifi-update.sh` — updates a robot's wifi connection, in one of two modes:

  ```bash
  # Mode A: update wifi on a live robot reachable over ethernet (SSH)
  ./scripts/tools/robot/wifi-update.sh --mode ssh --host 192.168.1.50 --ssid MyNetwork --password secret123

  # Mode B: arm a first-boot wifi setup job on the mounted bootfs (boot/firmware, FAT32)
  # partition of an SD card/USB disk
  ./scripts/tools/robot/wifi-update.sh --mode offline --mount /mnt/bootfs --ssid MyNetwork --password secret123
  ```

  Mode A runs over ethernet so the robot stays reachable even if the new wifi credentials are
  wrong, and applies immediately. Mode B arms a one-time "run on next boot" hook (the same
  mechanism Raspberry Pi Imager itself uses) on the mounted bootfs — the FAT32 boot/firmware
  partition that macOS, Windows, and Linux can all mount directly, unlike the ext4 rootfs — so
  the device writes its own NetworkManager connection profile and joins the network the next
  time it boots. It does NOT apply immediately, and works the same whether the card is a
  pristine unflashed image or one that's already been running in a robot for a long time. Both
  support `MECHA10_WIFI_*`-prefixed env vars (and an optional `--env-file`/
  `MECHA10_WIFI_ENV_FILE`) as an alternative to CLI flags — see `--help` for details.

## Maintainers

Build and publish scripts are in the [mecha10 monorepo](https://github.com/mecha-industries/mecha10).

See [`scripts/README.md`](https://github.com/mecha-industries/mecha10/blob/main/scripts/README.md) in that repository for release instructions.
