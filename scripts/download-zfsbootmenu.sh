#!/usr/bin/env bash
#
# download-zfsbootmenu.sh - Script to download ZFSBootMenu binaries
#

set -euo pipefail

# --- Configuration ---
BASE_URL="https://get.zfsbootmenu.org"
OUTPUT_DIR="$(pwd)/zbm-binaries"
BUILD_TYPE="release"
VERIFY_SIGNATURES=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Download ZFSBootMenu binaries from $BASE_URL/

OPTIONS:
    -o, --output-dir DIR     Output directory (default: $OUTPUT_DIR)
    -b, --build-type TYPE    Build type: release or recovery (default: release)
    -v, --verify             Download and verify GPG signatures
    -h, --help               Show this help message

EXAMPLES:
    # Download release binaries to default directory
    $(basename "$0")

    # Download recovery binaries to custom directory
    $(basename "$0") --output-dir ./zbm --build-type recovery

    # Download and verify signatures
    $(basename "$0") --verify
EOF
	exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
	-o | --output-dir)
		OUTPUT_DIR="$2"
		shift 2
		;;
	-b | --build-type)
		BUILD_TYPE="$2"
		shift 2
		;;
	-v | --verify)
		VERIFY_SIGNATURES=true
		shift
		;;
	-h | --help)
		usage
		;;
	*)
		log_error "Unknown option: $1"
		;;
	esac
done

if [[ "$BUILD_TYPE" != "release" && "$BUILD_TYPE" != "recovery" ]]; then
	log_error "Invalid build type: $BUILD_TYPE. Must be 'release' or 'recovery'."
fi

detect_latest_version() {
	log_info "Detecting latest ZFSBootMenu version..."
	# Fetching the version from the release page or redirect
	local version
	version=$(curl -sIL "$BASE_URL/latest" | grep -i "location:" | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
	if [[ -z "$version" ]]; then
		log_warn "Could not detect version via redirect, trying fallback method..."
		version=$(curl -s https://api.github.com/repos/zbm-dev/zfsbootmenu/releases/latest | grep -oP '"tag_name": "\K[^"]+')
	fi

	if [[ -z "$version" ]]; then
		log_error "Failed to detect latest version."
	fi
	echo "$version"
}

download_file() {
	local url="$1"
	local dest="$2"
	local desc="$3"

	log_info "Downloading $desc ($(basename "$dest"))..."
	curl -L -f -o "$dest" "$url"
	log_info "Downloaded: $dest"
}

verify_signatures() {
	local file="$1"
	local checksum_file="$2"
	local sig_file="$3"

	log_info "Verifying signatures..."

	# Check if gpg is installed
	if ! command -v gpg >/dev/null; then
		log_warn "gpg not found, skipping signature verification."
		return
	fi

	# Import ZFSBootMenu public key (if needed)
	# This is a placeholder as the specific key would need to be known
	# log_info "Importing ZFSBootMenu public key..."
	# curl -s https://get.zfsbootmenu.org/public.key | gpg --import

	# Verify checksum file signature
	if gpg --verify "$sig_file" "$checksum_file" >/dev/null 2>&1; then
		log_info "Checksum file signature verified."
	else
		log_warn "Checksum file signature verification failed or key not found."
	fi

	# Verify file checksum
	log_info "Verifying file checksum..."
	if sha256sum --check --ignore-missing "$checksum_file" >/dev/null 2>&1; then
		log_info "File checksum verified."
	else
		log_error "File checksum verification failed for $file."
	fi
}

main() {
	local version
	version=$(detect_latest_version)
	log_info "Latest version: $version"

	log_info "Creating output directory: $OUTPUT_DIR"
	mkdir -p "$OUTPUT_DIR"

	local components_url="$BASE_URL/components"
	if [[ "$BUILD_TYPE" == "recovery" ]]; then
		components_url="$BASE_URL/components/recovery"
	fi

	log_info "Fetching tarball filename from $components_url..."
	local tarball_name
	tarball_name=$(curl -sIL "$components_url" | grep -i "^content-disposition:" | sed -E 's/.*filename="?([^\"; ]+)"?/\1/' | tr -d '\r')

	if [[ -z "$tarball_name" ]]; then
		log_warn "Could not detect filename via headers, using fallback naming..."
		tarball_name="zfsbootmenu-${BUILD_TYPE}-x86_64-${version}.tar.gz"
	fi

	local tarball_path="$OUTPUT_DIR/$tarball_name"

	download_file "$components_url" "$tarball_path" "components tarball ($tarball_name)"

	if [[ "$VERIFY_SIGNATURES" == true ]]; then
		local checksum_path="$OUTPUT_DIR/sha256.txt"
		local sig_path="$OUTPUT_DIR/sha256.sig"

		download_file "$BASE_URL/sha256.txt" "$checksum_path" "checksum file"
		download_file "$BASE_URL/sha256.sig" "$sig_path" "signature file"

		cd "$OUTPUT_DIR"
		verify_signatures "$tarball_name" "sha256.txt" "sha256.sig"
		cd - >/dev/null
	fi

	log_info "Extracting tarball..."
	tar -xzf "$tarball_path" -C "$OUTPUT_DIR"

	# Find the directory that was just created (it should match zfsbootmenu-*)
	local extract_dir
	extract_dir=$(find "$OUTPUT_DIR" -maxdepth 1 -type d -name "zfsbootmenu-*" -not -path "$OUTPUT_DIR" | head -n 1)

	if [[ -n "$extract_dir" ]]; then
		log_info "Extracted to: $extract_dir"
		log_info "Extracted files:"
		ls -l "$extract_dir"
	else
		log_warn "Could not determine extraction directory."
	fi

	cd "$OUTPUT_DIR"
	ln -sf "$tarball_name" "zfsbootmenu-latest-${BUILD_TYPE}.tar.gz"
	log_info "Created symlink: zfsbootmenu-latest-${BUILD_TYPE}.tar.gz -> $tarball_name"
	cd - >/dev/null

	log_info "Download complete!"
	log_info "Output directory: $OUTPUT_DIR"
	log_info "Build type: $BUILD_TYPE"
}

main "$@"