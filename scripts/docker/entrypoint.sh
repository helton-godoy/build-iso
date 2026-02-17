#!/usr/bin/env bash
# =============================================================================
# @DEV_SCRIPT: entrypoint - Orquestra build da ISO dentro do container Docker
# @DEV_CATEGORY: docker
# @DEV_DEP: live-build (lb), rsync, tee
# @DEV_INPUT: /build/config-overrides (volume montado)
# @DEV_OUTPUT: /build/output/*.iso, /build/logs/*.log
# @DEV_MAKEFILE: build-iso
# =============================================================================
set -euo pipefail

SQUASHFS_COMPRESSION_TYPE="${SQUASHFS_COMPRESSION_TYPE:-zstd}"
SQUASHFS_COMPRESSION_LEVEL="${SQUASHFS_COMPRESSION_LEVEL:-15}"
ISO_COMPRESSION_TYPE="${ISO_COMPRESSION_TYPE:-xz}"

metrics_dir="/build/output/metrics"
mkdir -p "${metrics_dir}"

cat >"${metrics_dir}/squashfs-profile.env" <<EOF
SQUASHFS_COMPRESSION_TYPE=${SQUASHFS_COMPRESSION_TYPE}
SQUASHFS_COMPRESSION_LEVEL=${SQUASHFS_COMPRESSION_LEVEL}
ISO_COMPRESSION_TYPE=${ISO_COMPRESSION_TYPE}
EOF

# @DEV_FUNC: sync_overrides - Sincroniza config-overrides para workspace
echo "🚚 Syncing custom configurations..."
# We use a dedicated workspace to avoid cluttering the mount
rm -rf /build/live-build-workspace
mkdir -p /build/live-build-workspace
# Sync contents of config-overrides to the workspace root
# This structure expects config-overrides/config -> /build/live-build-workspace/config
cp -rv /build/config-overrides/* /build/live-build-workspace/

cd /build/live-build-workspace

echo "⚙️ Configuring live-build..."
if [[ -x ./auto/config ]]; then
  echo "ℹ️ Using config-overrides/auto/config with explicit squashfs profile"
  ./auto/config
else
  echo "⚠️ auto/config missing; using fallback lb config"
  lb config \
    --distribution trixie \
    --debian-installer false \
    --archive-areas "main contrib non-free non-free-firmware" \
    --memtest none \
    --source false \
    --binary-images iso-hybrid \
    --compression "${ISO_COMPRESSION_TYPE}" \
    --chroot-squashfs-compression-type "${SQUASHFS_COMPRESSION_TYPE}" \
    --chroot-squashfs-compression-level "${SQUASHFS_COMPRESSION_LEVEL}"
fi

# 3. Execute build
echo "🏗️ Starting ISO build process..."
mkdir -p /build/logs
lb build 2>&1 | tee "/build/logs/live-build-$(date +%Y%m%d-%H%M).log"

# 4. Organize artifacts
echo "📦 Organizing final artifacts..."
mkdir -p /build/output
# Move generated ISOs to output
mv ./*.iso /build/output/ || echo "No ISO found to move"
# Move intermediate files if needed, or just let them disappear with the container
# But keeping logs and manifests is good practice
mv ./*.contents /build/build/ 2>/dev/null || true
mv ./*.zsync /build/build/ 2>/dev/null || true

echo "✅ Build completed successfully!"
