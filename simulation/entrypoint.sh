#!/bin/bash
# Entrypoint for Godot simulation with Xvfb virtual display
#
# This script:
# 1. Starts Xvfb with GPU-friendly configuration
# 2. Waits for X server to be ready
# 3. Launches Godot with provided arguments

set -e

# Configure GPU/GL environment for optimal rendering
export __GL_SYNC_TO_VBLANK=0
export __GL_YIELD="NOTHING"

echo "=== Mecha10 Simulation Container ==="
echo "Starting Xvfb virtual display..."

# Start Xvfb with configuration suitable for Godot rendering
# Screen 0 at 1920x1080 with 24-bit color depth
Xvfb :99 -screen 0 1920x1080x24 \
    +extension GLX \
    +extension RENDER \
    +extension RANDR \
    +iglx \
    -nolisten tcp \
    -noreset \
    -ac &
XVFB_PID=$!

# Wait for Xvfb to be ready
echo "Waiting for Xvfb to start..."
for i in {1..10}; do
    if xdpyinfo -display :99 >/dev/null 2>&1; then
        echo "Xvfb ready on display :99"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "ERROR: Xvfb failed to start within 10 seconds"
        kill $XVFB_PID 2>/dev/null || true
        exit 1
    fi
    sleep 1
done

export DISPLAY=:99

# Verify GL/rendering capabilities
echo "Checking rendering capabilities..."
glxinfo | grep -E "(OpenGL vendor|OpenGL renderer|direct rendering)" 2>/dev/null || echo "GLX info not available (may still work)"

# Cleanup Xvfb on exit
cleanup() {
    echo "Shutting down Xvfb..."
    kill $XVFB_PID 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Launch Godot with all provided arguments
echo "Starting Godot simulation..."
echo "Command: godot $@"
echo ""

exec godot "$@"
