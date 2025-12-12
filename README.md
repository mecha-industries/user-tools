# Mecha10 User Tools

Public distribution repository for Mecha10 CLI and simulation assets.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/mecha-industries/user-tools/main/scripts/install.sh | sh
```

### Options

```bash
# Install specific version
MECHA10_VERSION=v0.1.6 curl -fsSL https://raw.githubusercontent.com/mecha-industries/user-tools/main/scripts/install.sh | sh

# Install to custom directory
MECHA10_INSTALL_DIR=/usr/local/bin curl -fsSL https://raw.githubusercontent.com/mecha-industries/user-tools/main/scripts/install.sh | sh
```

## What Gets Installed

The install script downloads pre-built binaries from GitHub Releases:

| Asset | Description |
|-------|-------------|
| `mecha10-{version}-{os}-{arch}.tar.gz` | CLI binary for your platform |

When you run `mecha10 dev` or simulation commands, the CLI will also download:

| Asset | Description |
|-------|-------------|
| `mecha10-simulation.tar.gz` | Godot project, robot models, environments |

Simulation assets are cached to `~/.mecha10/simulation/`.

## Supported Platforms

| OS | Architecture | Status |
|----|--------------|--------|
| macOS | x86_64 (Intel) | Supported |
| macOS | aarch64 (Apple Silicon) | Planned |
| Linux | x86_64 | Planned |
| Linux | aarch64 | Planned |
| Windows | x86_64 | Planned |
