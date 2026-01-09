#!/usr/bin/env bash
set -euo pipefail

DOCKERFILE="docker/Dockerfile"

echo "Running tests for Dockerfile..."

# Test 1: File existence
if [[ ! -f ${DOCKERFILE} ]]; then
	echo "FAIL: ${DOCKERFILE} does not exist."
	exit 1
fi

# Test 2: Base image
if ! grep -q "^FROM debian:trixie-slim" "${DOCKERFILE}"; then
	echo "FAIL: Base image is not debian:trixie-slim."
	exit 1
fi

# Test 3: Required packages
REQUIRED_PACKAGES=("live-build" "git" "curl")
CONTENT=$(cat "${DOCKERFILE}")

for pkg in "${REQUIRED_PACKAGES[@]}"; do
	if [[ ! ${CONTENT} =~ ${pkg} ]]; then
		echo "FAIL: Package '${pkg}' is not installed."
		exit 1
	fi
done

echo "PASS: Dockerfile meets all requirements."
exit 0
