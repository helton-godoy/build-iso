#!/usr/bin/env bash
set -euo pipefail

ISO_FILE=$(ls dist/*.iso 2>/dev/null | head -n 1)

echo "Running tests for ISO build artifact..."

# Test 1: ISO file exists
if [[ -z "$ISO_FILE" ]]; then
    echo "FAIL: No ISO file found in current directory."
    exit 1
fi

# Test 2: ISO size is reasonable (> 100MB)
ISO_SIZE=$(stat -c%s "$ISO_FILE")
MIN_SIZE=$((100 * 1024 * 1024))

if [[ $ISO_SIZE -lt $MIN_SIZE ]]; then
    echo "FAIL: ISO file '$ISO_FILE' is too small ($ISO_SIZE bytes). Build might have failed."
    exit 1
fi

echo "PASS: ISO artifact '$ISO_FILE' generated and has valid size."
exit 0
