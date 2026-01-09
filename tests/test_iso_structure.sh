#!/usr/bin/env bash
set -euo pipefail

# Use environment variable if provided, otherwise look for *.iso in current dir
if [[ -z ${ISO_FILE-} ]]; then
	ISO_FILE=$(ls *.iso 2>/dev/null | head -n 1)
fi

if [[ -z ${ISO_FILE} ]]; then
	echo "FAIL: No ISO file found."
	exit 1
fi

echo "Testing ISO structure for: ${ISO_FILE}"

# Helper function to check file existence in ISO
check_file() {
	local path="$1"
	if ! xorriso -indev "${ISO_FILE}" -ls "${path}" >/dev/null 2>&1; then
		echo "FAIL: File '${path}' not found in ISO."
		return 1
	else
		echo "PASS: File '${path}' found."
		return 0
	fi
}

# Check critical boot files
check_file "/live/vmlinuz"
check_file "/live/initrd.img"
check_file "/live/filesystem.squashfs"

# Check EFI support
check_file "/EFI/BOOT"

# Check ZFS presence in package list
if isoinfo -i "${ISO_FILE}" -R -x /live/filesystem.packages 2>/dev/null | grep -q "zfs"; then
	echo "PASS: ZFS packages found in filesystem.packages"
else
	echo "FAIL: ZFS packages NOT found in filesystem.packages"
	exit 1
fi

echo "ALL TESTS PASSED"
exit 0
