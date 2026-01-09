#!/usr/bin/env bash
set -euo pipefail

LIST_DIR="docker/config/package-lists"
ZFS_LIST="${LIST_DIR}/zfs.list.chroot"
TOOLS_LIST="${LIST_DIR}/tools.list.chroot"

echo "Running tests for package lists..."

# Test 1: Files existence
if [[ ! -f ${ZFS_LIST} ]]; then
	echo "FAIL: ${ZFS_LIST} does not exist."
	exit 1
fi

if [[ ! -f ${TOOLS_LIST} ]]; then
	echo "FAIL: ${TOOLS_LIST} does not exist."
	exit 1
fi

# Test 2: ZFS packages
ZFS_PKGS=("zfs-dkms" "zfsutils-linux")
for pkg in "${ZFS_PKGS[@]}"; do
	if ! grep -q "^${pkg}" "${ZFS_LIST}"; then
		echo "FAIL: Package '${pkg}' not found in ${ZFS_LIST}."
		exit 1
	fi
done

# Test 3: Tool packages
TOOL_PKGS=("gdisk" "dosfstools" "efibootmgr")
for pkg in "${TOOL_PKGS[@]}"; do
	if ! grep -q "^${pkg}" "${TOOLS_LIST}"; then
		echo "FAIL: Package '${pkg}' not found in ${TOOLS_LIST}."
		exit 1
	fi
done

echo "PASS: Package lists are correctly defined."
exit 0
