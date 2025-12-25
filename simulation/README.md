# Mecha10 Simulation Container

Headless Godot container for running robot simulations with full rendering support.

## Usage

```bash
# Pull the image
docker pull ghcr.io/mecha-industries/simulation:latest

# Run with your simulation project
docker run -v ./your-simulation:/simulation ghcr.io/mecha-industries/simulation --path /simulation
```

## Features

- Godot 4.3 with Xvfb virtual display
- Full OpenGL/Vulkan rendering (not headless mode)
- Camera and sensor data rendering works
- Mesa software rendering fallback

## Build Args

| Arg | Default | Description |
|-----|---------|-------------|
| `GODOT_VERSION` | `4.3` | Godot version to install |
| `GODOT_BUILD` | `stable` | Build type (stable, rc1, etc.) |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DISPLAY` | `:99` | X display for Xvfb |

## Building Locally

```bash
docker build -t simulation:local ./simulation
```
