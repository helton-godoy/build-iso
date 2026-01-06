#!/usr/bin/env bash
set -euo pipefail

# Configuration

IMAGE_NAME="debian-iso-builder"

DOCKER_DIR="docker/"

WORK_DIR="/work"

LOG_DIR="logs"

DIST_DIR="dist"



# Ensure directories exist

mkdir -p "$LOG_DIR" "$DIST_DIR"



# Host user info for permission fixing

HOST_UID=$(id -u)

HOST_GID=$(id -g)



# Build the builder image

echo "Building Docker image..."

docker build --progress=plain -t "$IMAGE_NAME" "$DOCKER_DIR" 2>&1 | tee "$LOG_DIR/docker-build.log"



# Determine command to run

if [[ "${1:-}" == "--run" ]]; then

    shift

    CMD=("$@")

else

    CMD=("lb" "build" "$@")

fi



# Run the builder (privileged needed for live-build mounting)

echo "Running in Docker: ${CMD[*]}"

# Use a temporary file to capture live-build output

docker run --rm --privileged \

    -v "$(pwd):$WORK_DIR" \

    "$IMAGE_NAME" \

    "${CMD[@]}" 2>&1 | tee "$LOG_DIR/lb-build.log"



# Move generated ISO to dist/

echo "Moving generated ISO to $DIST_DIR/..."

mv *.iso "$DIST_DIR/" 2>/dev/null || echo "No ISO file found to move."



# Fix permissions

# live-build runs as root inside the container, so created files are owned by root.

# We explicitly change ownership back to the host user.

echo "Fixing permissions..."

docker run --rm --privileged \

    -v "$(pwd):$WORK_DIR" \

    "$IMAGE_NAME" \

    chown -R "$HOST_UID:$HOST_GID" "$WORK_DIR"
