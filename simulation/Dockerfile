# Mecha10 Godot Simulation Container (Headless with Xvfb)
#
# This container runs Godot with virtual X display for headless simulation
# while still rendering camera/sensor data (unlike --headless flag).
#
# Usage:
#   docker pull ghcr.io/mecha-industries/simulation:latest
#   docker run -v ./simulation:/simulation ghcr.io/mecha-industries/simulation --path /simulation

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:99

WORKDIR /simulation

# Install Xvfb and dependencies for GPU-accelerated rendering
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Xvfb and X11 essentials
    xvfb \
    x11-utils \
    x11-xserver-utils \
    # OpenGL/Mesa for rendering
    libgl1 \
    libglx0 \
    libglx-mesa0 \
    libgl1-mesa-dri \
    mesa-utils \
    # Vulkan support (Godot 4 prefers Vulkan)
    mesa-vulkan-drivers \
    libvulkan1 \
    vulkan-tools \
    # EGL for headless GL
    libegl1 \
    # X11 client libraries that Godot needs
    libxrandr2 \
    libxi6 \
    libxcursor1 \
    libxinerama1 \
    libxxf86vm1 \
    libxfixes3 \
    # Download Godot
    wget \
    unzip \
    ca-certificates \
    # Process management
    procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Download and install Godot 4.x
ARG GODOT_VERSION=4.3
ARG GODOT_BUILD=stable
RUN wget -q https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_BUILD}/Godot_v${GODOT_VERSION}-${GODOT_BUILD}_linux.x86_64.zip \
    && unzip Godot_v${GODOT_VERSION}-${GODOT_BUILD}_linux.x86_64.zip \
    && mv Godot_v${GODOT_VERSION}-${GODOT_BUILD}_linux.x86_64 /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm Godot_v${GODOT_VERSION}-${GODOT_BUILD}_linux.x86_64.zip

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
