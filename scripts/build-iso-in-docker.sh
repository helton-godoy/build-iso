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
# Using -- "$@" is the standard way to pass arguments to bash -c
docker run --rm --privileged \
    -v "$(pwd):$WORK_DIR" \
    -v "$(pwd)/$BUILD_DIR:/build-outside" \
    -v "$(pwd)/$CACHE_DIR:/cache-outside" \
    "$IMAGE_NAME" \
    bash -c '
        # Create symlinks to the build/cache directories outside the project root
        ln -snf /build-outside/.build .build
        ln -snf /build-outside/chroot chroot
        ln -snf /build-outside/binary binary
        ln -snf /build-outside/local local
        ln -snf /cache-outside cache
        
        # Execute the requested command passed as arguments to bash -c
        "$@"
    ' -- "${CMD[@]}" 2>&1 | tee "$LOG_DIR/lb-build.log"

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
# We must include the same volume mappings to fix permissions on build and cache dirs
echo "Fixing permissions..."
docker run --rm --privileged \
    -v "$(pwd):$WORK_DIR" \
    -v "$(pwd)/$BUILD_DIR:/build-outside" \
    -v "$(pwd)/$CACHE_DIR:/cache-outside" \
    "$IMAGE_NAME" \
    chown -R "$HOST_UID:$HOST_GID" "$WORK_DIR" "/build-outside" "/cache-outside"

exit $EXIT_CODE
