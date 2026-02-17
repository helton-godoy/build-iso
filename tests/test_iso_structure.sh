#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${ISO_FILE:-}" ]]; then
  shopt -s nullglob
  iso_candidates=(./*.iso)
  shopt -u nullglob
  ISO_FILE="${iso_candidates[0]:-}"
fi
EXPECTED_SQUASHFS_COMPRESSION_TYPE="${EXPECTED_SQUASHFS_COMPRESSION_TYPE:-}"

if [[ -z "$ISO_FILE" || ! -f "$ISO_FILE" ]]; then
  echo "[FAIL] No ISO file found in current directory."
  exit 1
fi

check_file() {
  local path="$1"
  if xorriso -indev "$ISO_FILE" -ls "$path" >/dev/null 2>&1; then
    echo "[PASS] Found: $path"
  else
    echo "[FAIL] Missing: $path"
    exit 1
  fi
}

echo "[TEST] Checking ISO: $ISO_FILE"

check_file /live/vmlinuz
check_file /live/initrd.img
check_file /live/filesystem.squashfs

check_file /EFI/BOOT

echo "[TEST] Checking for ZFS packages..."
if isoinfo -R -i "$ISO_FILE" -x /live/filesystem.packages | grep -q zfs; then
  echo "[PASS] ZFS packages found"
else
  echo "[FAIL] ZFS packages not found"
  exit 1
fi

if [[ -n "$EXPECTED_SQUASHFS_COMPRESSION_TYPE" ]]; then
  echo "[TEST] Checking squashfs compression profile..."

  if ! command -v unsquashfs >/dev/null 2>&1; then
    echo "[FAIL] unsquashfs not found for compression validation"
    exit 1
  fi

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf -- "$tmp_dir"' EXIT

  xorriso -osirrox on -indev "$ISO_FILE" -extract /live/filesystem.squashfs "$tmp_dir/filesystem.squashfs" >/dev/null 2>&1
  actual_compression="$(unsquashfs -s "$tmp_dir/filesystem.squashfs" | awk -F': *' '/Compression/{print tolower($2); exit}')"

  if [[ "$actual_compression" != "${EXPECTED_SQUASHFS_COMPRESSION_TYPE,,}" ]]; then
    echo "[FAIL] SquashFS compression mismatch: expected=${EXPECTED_SQUASHFS_COMPRESSION_TYPE} actual=${actual_compression:-unknown}"
    exit 1
  fi

  echo "[PASS] SquashFS compression validated: $actual_compression"
fi

echo "ALL TESTS PASSED"
exit 0
