# Mecha10 User Tools

Public distribution repository for Mecha10 CLI, Launcher, and simulation assets.

## CLI Install

Install the Mecha10 CLI for development:

```bash
curl -fsSL https://raw.githubusercontent.com/mecha-industries/user-tools/main/scripts/install.sh | sh
```

### CLI Options

```bash
# Install specific version
MECHA10_VERSION=v0.1.42 curl -fsSL https://raw.githubusercontent.com/mecha-industries/user-tools/main/scripts/install.sh | sh

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
MECHA10_VERSION=v0.1.42 curl -fsSL https://raw.githubusercontent.com/mecha-industries/user-tools/main/scripts/install-launcher.sh | sh

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
