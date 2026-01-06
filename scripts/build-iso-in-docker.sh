#!/usr/bin/env bash
set -euo pipefail

# Configuration
IMAGE_NAME="debian-iso-builder"
DOCKER_DIR="docker/"
WORK_DIR="/work"
LOG_DIR="logs"
DIST_DIR="dist"
BUILD_DIR="build"
CACHE_DIR="cache"

# Ensure directories exist
mkdir -p "$LOG_DIR" "$DIST_DIR" "$CACHE_DIR"
mkdir -p "$BUILD_DIR/.build" "$BUILD_DIR/chroot" "$BUILD_DIR/binary" "$BUILD_DIR/local"

# Host user info for permission fixing
HOST_UID=$(id -u)
HOST_GID=$(id -g)

# Build the builder image
echo "Building Docker image..."
docker build --progress=plain -t "$IMAGE_NAME" "$DOCKER_DIR" 2>&1 | tee "$LOG_DIR/docker-build.log"

# Determine command to run
if [[ $# -gt 0 ]]; then
    CMD=("$@")
else
    CMD=("lb" "build")
fi

echo "Running in Docker: ${CMD[*]}"

# We use a wrapper to setup symlinks inside the container.
# This avoids "Device or resource busy" errors when lb clean tries to rm directories
# that are directly mounted as volumes.
docker run --rm --privileged \
    -v "$(pwd):$WORK_DIR" \
    -v "$(pwd)/$BUILD_DIR:/build-outside" \
    -v "$(pwd)/$CACHE_DIR:/cache-outside" \
    "$IMAGE_NAME" \
    bash -c "
        # Create symlinks to the build/cache directories outside the project root in container
        # but inside the volume-mapped space.
        ln -snf /build-outside/.build .build
        ln -snf /build-outside/chroot chroot
        ln -snf /build-outside/binary binary
        ln -snf /build-outside/local local
        ln -snf /cache-outside cache
        
        # Execute the requested command
        "${CMD[@]}"
    " 2>&1 | tee "$LOG_DIR/lb-build.log"

EXIT_CODE=${PIPESTATUS[0]}

# Move generated ISO to dist/ if build was successful
if [[ $EXIT_CODE -eq 0 ]]; then
    if ls "$BUILD_DIR"/binary/*.iso 1>/dev/null 2>&1; then
        echo "Moving generated ISO to $DIST_DIR/..."
        mv "$BUILD_DIR"/binary/*.iso "$DIST_DIR/"
    elif ls *.iso 1>/dev/null 2>&1; then
         echo "Moving generated ISO from root to $DIST_DIR/"
         mv *.iso "$DIST_DIR/"
    fi
else
    echo "Build command failed with exit code $EXIT_CODE"
fi

# Fix permissions
# live-build runs as root inside the container, so created files are owned by root.
# We explicitly change ownership back to the host user.
echo "Fixing permissions..."
docker run --rm --privileged \
    -v "$(pwd):$WORK_DIR" \
    "$IMAGE_NAME" \
    chown -R "$HOST_UID:$HOST_GID" "$WORK_DIR" "/build-outside" "/cache-outside"

exit $EXIT_CODE
