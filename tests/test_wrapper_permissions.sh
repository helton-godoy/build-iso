#!/usr/bin/env bash
set -euo pipefail

WRAPPER="scripts/build-iso-in-docker.sh"
TEST_FILE="test_artifact_$(date +%s)"

# Function to clean up
cleanup() {
    rm -f "$TEST_FILE"
}
trap cleanup EXIT

echo "Running wrapper permission test..."

# Execute the wrapper with a command to create a file
# We expect the wrapper to support running arbitrary commands for testing purposes
# or that we can override the 'lb build' default.
# We use a custom flag --run to indicate we want to run a raw command
"$WRAPPER" --run touch "$TEST_FILE" || true

# Check if file was created
if [[ ! -f "$TEST_FILE" ]]; then
    echo "FAIL: Test file was not created. Wrapper might not support custom commands."
    exit 1
fi

# Check ownership
FILE_UID=$(stat -c '%u' "$TEST_FILE")
CURRENT_UID=$(id -u)

if [[ "$FILE_UID" != "$CURRENT_UID" ]]; then
    echo "FAIL: File is owned by UID $FILE_UID, expected $CURRENT_UID."
    exit 1
fi

echo "PASS: File created with correct ownership."
exit 0
