#!/usr/bin/env bash
set -euo pipefail

# Use environment variable or default path
ISO_FILE="${ISO_FILE:-./live-image-amd64.hybrid.iso}"

if [[ ! -f "$ISO_FILE" ]]; then
    echo "FAIL: ISO file not found at $ISO_FILE"
    exit 1
fi

echo "Testing ISO structural pool for: $ISO_FILE"

check_path() {
    local path="$1"
    if ! xorriso -indev "$ISO_FILE" -ls "$path" >/dev/null 2>&1; then
        echo "FAIL: Path '$path' not found in ISO."
        return 1
    else
        echo "PASS: Path '$path' found."
        return 0
    fi
}

ERRORS=0
check_path "/pool" || ERRORS=$((ERRORS + 1))
check_path "/dists" || ERRORS=$((ERRORS + 1))
check_path "/live/vmlinuz" || ERRORS=$((ERRORS + 1))
check_path "/live/initrd.img" || ERRORS=$((ERRORS + 1))

if [[ $ERRORS -gt 0 ]]; then
    echo "FAIL: ISO structure verification failed with $ERRORS errors."
    exit 1
fi

echo "ALL POOL TESTS PASSED"
exit 0
