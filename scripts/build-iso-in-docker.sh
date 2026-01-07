#!/usr/bin/env bash
set -euo pipefail

# Configuration
IMAGE_NAME="debian-iso-builder"
DOCKER_DIR="docker/"
WORK_DIR="/work"

# Artifacts and Processing directories (now inside docker/artifacts/)
# We use relative paths from the project root for the host.
ARTIFACTS_DIR="docker/artifacts"
LOG_DIR="$ARTIFACTS_DIR/logs"
DIST_DIR="$ARTIFACTS_DIR/dist"
BUILD_DIR="$ARTIFACTS_DIR/build"
CACHE_DIR="$ARTIFACTS_DIR/cache"

# Ensure directories exist on host
mkdir -p "$LOG_DIR" "$DIST_DIR" "$CACHE_DIR" "$BUILD_DIR"

# Host user info for permission fixing
HOST_UID=$(id -u)
HOST_GID=$(id -g)

# Build the builder image
echo "Building Docker image..."
docker build --progress=plain -t "$IMAGE_NAME" "$DOCKER_DIR" 2>&1 | tee "$LOG_DIR/docker-build.log"

# Inject ZFSBootMenu binaries if they exist
ZBM_SOURCE="zbm-binaries"
ZBM_DEST="config/includes.chroot/usr/share/zfsbootmenu"
if [[ -d "$ZBM_SOURCE" ]]; then
    echo "Injecting ZFSBootMenu binaries..."
    mkdir -p "$ZBM_DEST"
    LATEST_ZBM_DIR=$(find "$ZBM_SOURCE" -maxdepth 1 -type d -name "zfsbootmenu-release-*" | sort -V | tail -n 1)
    if [[ -n "$LATEST_ZBM_DIR" ]]; then
        cp -v "$LATEST_ZBM_DIR"/vmlinuz-bootmenu "$ZBM_DEST/" || true
        cp -v "$LATEST_ZBM_DIR"/initramfs-bootmenu.img "$ZBM_DEST/" || true
        find "$LATEST_ZBM_DIR" -name "*.EFI" -exec cp -v {} "$ZBM_DEST/" \; || true
    fi
fi

# Determine command to run
if [[ $# -gt 0 ]]; then
    CMD=("$@")
else
    CMD=("lb" "build")
fi

echo "Running in Docker: ${CMD[*]}"

# IMPORTANT: We map the whole project root to /work.
# We also map the artifacts directories to their expected locations in the container
# root if we wanted to keep them outside, but live-build is very sensitive to 
# cross-device links. To keep it simple and functional, we let live-build work
# in the project root inside the container, and we link/move the results.
#
# Strategy:
# 1. Map the project root.
# 2. Map the artifacts subdirs specifically if we want them to persist correctly
#    on the same filesystem to allow hardlinks.
#
# Actually, the most robust way is to let live-build create chroot/ and binary/ 
# in the current directory, and we move them to docker/artifacts if needed.
# But since we want them hidden, we can link them.

docker run --rm --privileged \
    -v "$(pwd):$WORK_DIR" \
    -e BUILD_DIR="$BUILD_DIR" \
    -e CACHE_DIR="$CACHE_DIR" \
    "$IMAGE_NAME" \
    bash -c ' 
        # Setup links for live-build to use our artifacts directory
        # This keeps the root clean while allowing hardlinks if the FS supports it.
        # Note: If docker/artifacts is on the same FS as the root, hardlinks work.
        mkdir -p "$BUILD_DIR"/.build "$BUILD_DIR"/chroot "$BUILD_DIR"/binary "$BUILD_DIR"/local "$CACHE_DIR"
        
        ln -snf "$BUILD_DIR"/.build .build
        ln -snf "$BUILD_DIR"/chroot chroot
        ln -snf "$BUILD_DIR"/binary binary
        ln -snf "$BUILD_DIR"/local local
        ln -snf "$CACHE_DIR" cache
        
        # Execute the requested command
        "$@"
    ' -- "${CMD[@]}" 2>&1 | tee "$LOG_DIR/lb-build.log"

EXIT_CODE=${PIPESTATUS[0]}

# Move generated ISO to dist/ if build was successful
if [[ $EXIT_CODE -eq 0 ]]; then
    if ls *.iso 1>/dev/null 2>&1; then
         echo "Moving generated ISO to $DIST_DIR/..."
         mv *.iso "$DIST_DIR/"
    fi
else
    echo "Build command failed with exit code $EXIT_CODE"
fi

# Fix permissions
echo "Fixing permissions..."
docker run --rm --privileged \
    -v "$(pwd):$WORK_DIR" \
    "$IMAGE_NAME" \
    chown -R "$HOST_UID:$HOST_GID" "$WORK_DIR"
 
exit $EXIT_CODE
