# Mecha10 User Tools

Public distribution repository for Mecha10 CLI, Launcher, Docker images, and simulation assets.

## Table of Contents

- [CLI Install](#cli-install)
- [Launcher Install](#launcher-install-linux)
- [Docker Images](#docker-images)
- [Supported Platforms](#supported-platforms)

## CLI Install

Install the Mecha10 CLI for development:

```bash
curl -fsSL https://raw.githubusercontent.com/mecha-industries/user-tools/main/scripts/install.sh | sh
```

### CLI Options

```bash
# Install specific version
MECHA10_VERSION=v0.1.44 curl -fsSL https://raw.githubusercontent.com/mecha-industries/user-tools/main/scripts/install.sh | sh

# Install to custom directory
MECHA10_INSTALL_DIR=/usr/local/bin curl -fsSL https://raw.githubusercontent.com/mecha-industries/user-tools/main/scripts/install.sh | sh
```

## Launcher Install (Linux)

Install the Mecha10 Launcher on your robot/edge device to automatically download and run robot binaries:

```bash
curl -fsSL https://raw.githubusercontent.com/mecha-industries/user-tools/main/scripts/install-launcher.sh | sh
```

### Launcher Options

```bash
# Install specific version
MECHA10_VERSION=v0.1.44 curl -fsSL https://raw.githubusercontent.com/mecha-industries/user-tools/main/scripts/install-launcher.sh | sh

# Skip systemd service setup
MECHA10_NO_SERVICE=1 curl -fsSL https://raw.githubusercontent.com/mecha-industries/user-tools/main/scripts/install-launcher.sh | sh
```

### Launcher Setup

After installation, configure the launcher:

1. **Login** (on your development machine):
   ```bash
   mecha10 auth login
   ```

2. **Copy credentials** to your robot:
   ```bash
   scp ~/.mecha10/credentials.json robot@your-robot:~/.mecha10/
   ```

3. **Create launcher config** on the robot at `~/.mecha10/launcher/config.json`:
   ```json
   {
     "robot_project": {
       "name": "your-project-name",
       "install_dir": "~/mecha10/robots"
     },
     "platform_url": "https://mecha.industries",
     "robot_id": "your-robot-id",
     "auto_update": true,
     "update_check_interval_seconds": 300
   }
   ```

4. **Start the launcher**:
   ```bash
   mecha10-launcher start
   ```

   Or if installed as a service:
   ```bash
   systemctl --user start mecha10-launcher
   ```

### Launcher Workflow

1. **Build** your robot binary:
   ```bash
   mecha10 build robot --docker
   ```

2. **Upload** to the binary registry:
   ```bash
   mecha10 upload
   ```

3. The launcher on your robot will automatically download and run the new version.

## Docker Images

All Docker images are published to GitHub Container Registry under `ghcr.io/mecha-industries/`.

### User-Facing Images (Public)

These images are used by end users and are publicly accessible.

#### mecha10-remote

Runs AI/ML nodes (object-detector, image-classifier, llm-command) that require platform-specific dependencies like ONNX Runtime.

```bash
# Pull the image
docker pull ghcr.io/mecha-industries/mecha10-remote:0.1.44

# Or use via CLI (automatically pulls)
mecha10 remote up
```

| Image | Description |
|-------|-------------|
| `ghcr.io/mecha-industries/mecha10-remote:latest` | Latest stable release |
| `ghcr.io/mecha-industries/mecha10-remote:0.1.44` | Specific version |

#### simulation

Runs Godot-based simulation for robot testing and development.

```bash
# Pull the image
docker pull ghcr.io/mecha-industries/simulation:latest

# Or use via CLI (automatically pulls)
mecha10 sim run
```

| Image | Description |
|-------|-------------|
| `ghcr.io/mecha-industries/simulation:latest` | Latest with Godot 4.3 |
| `ghcr.io/mecha-industries/simulation:0.1.44` | Specific version |
| `ghcr.io/mecha-industries/simulation:godot-4.3` | Godot version tag |

### Control Plane Images (Private)

These images are used for self-hosted control plane deployments.

#### user-tools services

| Image | Description | Port |
|-------|-------------|------|
| `ghcr.io/mecha-industries/user-tools/dashboard` | Web dashboard UI | 3000 |
| `ghcr.io/mecha-industries/user-tools/auth` | Authentication service | 3000 |
| `ghcr.io/mecha-industries/user-tools/websocket-relay` | WebSocket relay for robot communication | 3004 |

#### Deployment

```bash
# Pull control plane images
docker pull ghcr.io/mecha-industries/user-tools/dashboard:0.1.44
docker pull ghcr.io/mecha-industries/user-tools/auth:0.1.44
docker pull ghcr.io/mecha-industries/user-tools/websocket-relay:0.1.44

# Or use docker-compose from mecha10 monorepo
cd mecha10
docker compose up -d dashboard auth websocket-relay
```

### Building Images (Maintainers)

For maintainers who need to build and publish images:

```bash
# Authenticate to GHCR
gh auth token | docker login ghcr.io -u USERNAME --password-stdin

# Build and push mecha10-remote (from mecha10 repo)
./scripts/build-remote-image.sh --push

# Build and push simulation (from mecha10 repo)
./scripts/publish-simulation-image.sh 0.1.44

# Build and push user-tools images (from this repo)
./scripts/publish-docker-images.sh --mecha10-path ~/src/mecha10
```

### Building Launcher Binary

Build the launcher binary for testing or development:

```bash
# Build for x86_64 (default)
./scripts/build-launcher.sh --mecha10-path ~/src/mecha10

# Build for aarch64 (Raspberry Pi 5)
./scripts/build-launcher.sh --arch aarch64 --mecha10-path ~/src/mecha10
```

The binary is output to `mecha10/dist/mecha10-launcher` and can be used with the e2e test:

```bash
cd ~/src/mecha10
./scripts/test-launcher-e2e.sh --arm64
```

## What Gets Installed

### CLI Assets

| Asset | Description |
|-------|-------------|
| `mecha10-{version}-{os}-{arch}.tar.gz` | CLI binary for your platform |

When you run `mecha10 dev` or simulation commands, the CLI will also download:

| Asset | Description |
|-------|-------------|
| `mecha10-simulation.tar.gz` | Godot project, robot models, environments |

Simulation assets are cached to `~/.mecha10/simulation/`.

### Launcher Assets

| Asset | Description |
|-------|-------------|
| `mecha10-launcher-{version}-linux-{arch}.tar.gz` | Launcher binary (Linux only) |

## Supported Platforms

### CLI

| OS | Architecture | Status |
|----|--------------|--------|
| macOS | x86_64 (Intel) | Supported |
| macOS | aarch64 (Apple Silicon) | Supported |
| Linux | x86_64 | Supported |
| Linux | aarch64 | Planned |
| Windows | x86_64 | Planned |

### Launcher

| OS | Architecture | Status |
|----|--------------|--------|
| Linux | x86_64 | Supported |
| Linux | aarch64 (Pi 5) | Supported |

### Docker Images

| Image | linux/amd64 | linux/arm64 |
|-------|-------------|-------------|
| mecha10-remote | ✅ | ❌ |
| simulation | ✅ | ❌ |
| user-tools/* | ✅ | ❌ |
