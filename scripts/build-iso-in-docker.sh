#!/usr/bin/env bash
set -euo pipefail

# Configuration
IMAGE_NAME="debian-iso-builder"
DOCKER_DIR="docker/"
WORK_DIR="/work"

# Host user info for permission fixing
HOST_UID=$(id -u)
HOST_GID=$(id -g)

# Build the builder image
echo "Building Docker image..."
docker build -t "$IMAGE_NAME" "$DOCKER_DIR"

# Determine command to run
if [[ "${1:-}" == "--run" ]]; then
    shift
    CMD=("$@")
else
    CMD=("lb" "build" "$@")
fi

# Run the builder (privileged needed for live-build mounting)
echo "Running in Docker: ${CMD[*]}"
docker run --rm -it --privileged \
    -v "$(pwd):$WORK_DIR" \
    "$IMAGE_NAME" \
    "${CMD[@]}"

# Fix permissions
# live-build runs as root inside the container, so created files are owned by root.
# We explicitly change ownership back to the host user.
echo "Fixing permissions..."
docker run --rm --privileged \
    -v "$(pwd):$WORK_DIR" \
    "$IMAGE_NAME" \
    chown -R "$HOST_UID:$HOST_GID" "$WORK_DIR"