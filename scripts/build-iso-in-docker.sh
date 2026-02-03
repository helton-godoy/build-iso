#!/usr/bin/env bash
set -euo pipefail

# Configuration
IMAGE_NAME="debian-iso-builder"
DOCKER_DIR="scripts/docker/"
WORK_DIR="/work"

# Artifacts and Processing directories
LOG_DIR="logs"
DIST_DIR="output"
BUILD_DIR="build"
CACHE_DIR="cache"

# Clean up legacy symlinks if they exist on host
for link in config binary cache local .build chroot; do
    if [ -L "$link" ]; then
        echo "Removing legacy symlink: $link"
        rm -f "$link"
    fi
done

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
# Inject directly into the isolated build config
ZBM_DEST="$BUILD_DIR/config/include.chroot/usr/share/zfsbootmenu"
if [[ -d "$ZBM_SOURCE" ]]; then
    echo "Injecting ZFSBootMenu binaries into build/config..."
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

# We map the whole project root to /work and set BUILD_DIR as the working directory.
# Both build/ and cache/ are on the same volume to allow hardlinks.
docker run --rm --privileged \
    -v "$(pwd):$WORK_DIR" \
    -w "$WORK_DIR/$BUILD_DIR" \
    "$IMAGE_NAME" \
    bash -c "
        # Link cache directory if needed (same volume as /work/build)
        if [ ! -d 'cache' ] && [ ! -L 'cache' ]; then
            ln -snf \"$WORK_DIR/$CACHE_DIR\" cache
        fi
        
        echo \"--- DEBUG: Filesystem check --- \"
        df -h . \"$WORK_DIR/$CACHE_DIR\"
        
        # Ensure config stage is run if it is a fresh build or auto/config exists
        if [ -d 'auto' ] && [ ! -d '.build' ]; then
            echo \"Running lb config (auto)...\"
            lb config
        fi
        
        # Execute the requested command
        echo \"Executing: \$@\"
        \"\$@\"
    " bash "${CMD[@]}" 2>&1 | tee "$LOG_DIR/lb-build.log"

EXIT_CODE=${PIPESTATUS[0]}

# The ISO is generated inside build/
if [[ $EXIT_CODE -eq 0 ]]; then
    if ls "$BUILD_DIR"/*.iso 1>/dev/null 2>&1; then
         echo "Moving generated ISO to $DIST_DIR/..."
         mv "$BUILD_DIR"/*.iso "$DIST_DIR/"
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
