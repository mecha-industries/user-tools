# Mecha10 User Tools

[![CI](https://github.com/mecha-industries/user-tools/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/mecha-industries/user-tools/actions/workflows/ci.yml) ![License](https://img.shields.io/badge/license-Unknown-blue) ![Last commit](https://img.shields.io/github/last-commit/mecha-industries/user-tools) ![Top language](https://img.shields.io/github/languages/top/mecha-industries/user-tools)

Public distribution repository for Mecha10 CLI and Launcher binaries.

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
- `servo_test.py` — sweeps a servo through min/mid/max pulse widths over the kernel's
  hardware PWM sysfs interface.
- `wifi-update.sh` — updates a robot's wifi connection, in one of two modes:

  ```bash
  # Mode A: update wifi on a live robot reachable over ethernet (SSH)
  ./scripts/tools/robot/wifi-update.sh --mode ssh --host 192.168.1.50 --ssid MyNetwork --password secret123

  # Mode B: write a wifi profile onto an offline/unmounted-boot SD card or USB disk
  ./scripts/tools/robot/wifi-update.sh --mode offline --mount /mnt/sdcard --ssid MyNetwork --password secret123
  ```

  Mode A runs over ethernet so the robot stays reachable even if the new wifi credentials are
  wrong. Mode B writes a NetworkManager connection profile directly onto a mounted (not
  currently booted) Raspberry Pi OS Bookworm+ boot disk, so the device joins the network
  automatically on its next boot. Both support `MECHA10_WIFI_*`-prefixed env vars (and an
  optional `--env-file`/`MECHA10_WIFI_ENV_FILE`) as an alternative to CLI flags — see
  `--help` for details.

## Maintainers

Build and publish scripts are in the [mecha10 monorepo](https://github.com/mecha-industries/mecha10).

See [`scripts/README.md`](https://github.com/mecha-industries/mecha10/blob/main/scripts/README.md) in that repository for release instructions.
