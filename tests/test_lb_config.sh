#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="config"
BINARY_CONFIG="docker/config/binary"
CHROOT_CONFIG="docker/config/chroot"
BOOTSTRAP_CONFIG="docker/config/bootstrap"

echo "Running tests for Live-Build configuration..."

# Test 1: Config directory exists
if [[ ! -d "config" ]]; then
    echo "FAIL: config directory does not exist."
    exit 1
fi

# Test 2: Distribution is trixie
if ! grep -q "LB_DISTRIBUTION=\"trixie\"" "$BOOTSTRAP_CONFIG" 2>/dev/null; then
    echo "FAIL: Distribution is not set to 'trixie' in $BOOTSTRAP_CONFIG."
    exit 1
fi

# Test 3: Archive areas
if ! grep -q "main contrib non-free non-free-firmware" "$BOOTSTRAP_CONFIG" 2>/dev/null; then
    echo "FAIL: Archive areas do not include 'main contrib non-free non-free-firmware' in $BOOTSTRAP_CONFIG."
    exit 1
fi

# Test 4: Binary image type
if ! grep -q "LB_IMAGE_TYPE=\"iso-hybrid\"" "$BOOTSTRAP_CONFIG" 2>/dev/null && \
   ! grep -q "LB_IMAGE_TYPE=\"iso-hybrid\"" "$BINARY_CONFIG" 2>/dev/null; then
    echo "FAIL: Binary image type is not 'iso-hybrid'."
    exit 1
fi

echo "PASS: Live-Build configuration initialized correctly."
exit 0
