#!/usr/bin/env bash
set -euo pipefail

HOOK_FILE="config/hooks/live/copy-zfsbootmenu.hook.chroot"

echo "Running tests for ZFSBootMenu integration hook..."

# Test 1: Hook file exists and is executable
if [[ ! -f "$HOOK_FILE" ]]; then
    echo "FAIL: $HOOK_FILE does not exist."
    exit 1
fi

if [[ ! -x "$HOOK_FILE" ]]; then
    echo "FAIL: $HOOK_FILE is not executable."
    exit 1
fi

# Test 2: Hook content (must copy ZBM binaries)
CONTENT=$(cat "$HOOK_FILE")

if [[ ! "$CONTENT" =~ "zbm-binaries" ]]; then
    echo "FAIL: Hook does not reference 'zbm-binaries'."
    exit 1
fi

if [[ ! "$CONTENT" =~ "mkdir -p" ]]; then
    echo "FAIL: Hook does not create target directories."
    exit 1
fi

echo "PASS: ZFSBootMenu hook is correctly defined."
exit 0
