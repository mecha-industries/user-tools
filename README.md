# Mecha10 User Tools

Public distribution repository for Mecha10 CLI and Launcher binaries.

## CLI Installation

Install the Mecha10 CLI on your development machine:

```bash
curl -fsSL https://raw.githubusercontent.com/mecha-industries/user-tools/main/scripts/install.sh | sh
```

### Options

```bash
# Install specific version
MECHA10_VERSION=0.1.44 curl -fsSL ... | sh

# Install to custom directory
MECHA10_INSTALL_DIR=/usr/local/bin curl -fsSL ... | sh
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
curl -fsSL https://raw.githubusercontent.com/mecha-industries/user-tools/main/scripts/install-launcher.sh | sh
```

### Options

```bash
# Install specific version
MECHA10_VERSION=0.1.44 curl -fsSL ... | sh

# Skip systemd service setup
MECHA10_NO_SERVICE=1 curl -fsSL ... | sh
```

### Launcher Setup

After installation:

1. **Login** on your development machine:
   ```bash
   mecha10 auth login
   ```

2. **Copy credentials** to your robot:
   ```bash
   scp ~/.mecha10/credentials.json robot@your-robot:~/.mecha10/
   ```

3. **Configure** on the robot (`~/.mecha10/launcher/config.json`):
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

4. **Start** the launcher:
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

Downloads from this repository's GitHub Releases:
- `mecha10-v{VERSION}-{os}-{arch}.tar.gz`

When you run `mecha10 sim` commands, additional assets are downloaded:
- `mecha10-simulation.tar.gz` - Godot project, robot models, environments

### Launcher

Downloads from this repository's GitHub Releases:
- `mecha10-launcher-v{VERSION}-linux-{arch}.tar.gz`

## Docker Images

Users can also access public Docker images:

```bash
# Remote node runner (for AI/ML nodes)
docker pull ghcr.io/mecha-industries/mecha10-remote:latest

# Or via CLI
mecha10 remote up
```

## Maintainers

Build and publish scripts are in the [mecha10 monorepo](https://github.com/mecha-industries/mecha10).

See `PUBLISHING.md` in that repository for release instructions.
