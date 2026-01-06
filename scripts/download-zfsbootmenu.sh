#!/usr/bin/env bash
#
# download-zfsbootmenu.sh - Download ZFSBootMenu binaries
#
# Downloads latest ZFSBootMenu binaries (vmlinuz, initramfs, EFI) from
# https://get.zfsbootmenu.org/ and extracts them to a specified directory.
#
# Usage:
#   ./scripts/download-zfsbootmenu.sh [--output-dir DIR] [--build-type release|recovery] [--verify]

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly BASE_URL="https://get.zfsbootmenu.org"
readonly DEFAULT_OUTPUT_DIR="$PROJECT_ROOT/zbm-binaries"
readonly DEFAULT_BUILD_TYPE="release"

OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
BUILD_TYPE="$DEFAULT_BUILD_TYPE"
VERIFY_SIGNATURES=false

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log_info() {
	echo -e "${GREEN}[INFO]${NC} $*" >&2
}

log_warn() {
	echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
	echo -e "${RED}[ERROR]${NC} $*" >&2
}

show_usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Download ZFSBootMenu binaries from https://get.zfsbootmenu.org/

OPTIONS:
    -o, --output-dir DIR     Output directory (default: $DEFAULT_OUTPUT_DIR)
    -b, --build-type TYPE    Build type: release or recovery (default: $DEFAULT_BUILD_TYPE)
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
}

check_dependencies() {
	local missing_deps=()

	command -v curl >/dev/null 2>&1 || missing_deps+=("curl")
	command -v tar >/dev/null 2>&1 || missing_deps+=("tar")

	if [[ "${#missing_deps[@]}" -gt 0 ]]; then
		log_error "Missing dependencies: ${missing_deps[*]}"
		log_error "Install with: apt install curl tar"
		exit 1
	fi

	if [[ "$VERIFY_SIGNATURES" == true ]]; then
		command -v gpg >/dev/null 2>&1 || missing_deps+=("gpg")
		if [[ "${#missing_deps[@]}" -gt 0 ]]; then
			log_error "Missing dependencies for signature verification: ${missing_deps[*]}"
			log_error "Install with: apt install gpg"
			exit 1
		fi
	fi
}

detect_latest_version() {
	log_info "Detecting latest ZFSBootMenu version..."
	local version
	version=$(curl -sI "$BASE_URL/efi" | grep -i location | grep -oP 'v\d+\.\d+\.\d+' | head -1)

	if [[ -z "$version" ]]; then
		log_error "Failed to detect latest version"
		exit 1
	fi

	log_info "Latest version: $version"
	echo "$version"
}

download_file() {
	local url="$1"
	local output="$2"
	local desc="$3"

	log_info "Downloading $desc..."
	if ! curl -sSL --fail -o "$output" "$url"; then
		log_error "Failed to download $desc from $url"
		exit 1
	fi
	log_info "Downloaded: $output"
}

verify_signatures() {
	local tarball="$1"
	local checksum_file="$2"
	local sig_file="$3"

	log_info "Verifying signatures..."

	if ! gpg --list-keys "release@zfsonlinux.org" >/dev/null 2>&1; then
		log_info "Importing ZFSBootMenu GPG key..."
		curl -sSL "$BASE_URL/zfsbootmenu.pub" | gpg --import
	fi

	if ! gpg --verify "$sig_file" "$checksum_file"; then
		log_error "GPG signature verification failed"
		exit 1
	fi
	log_info "GPG signature verified"

	if ! sha256sum -c "$checksum_file" --ignore-missing; then
		log_error "Checksum verification failed"
		exit 1
	fi
	log_info "Checksum verified"
}

main() {
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
			show_usage
			exit 0
			;;
		*)
			log_error "Unknown option: $1"
			show_usage
			exit 1
			;;
		esac
	done

	if [[ "$BUILD_TYPE" != "release" && "$BUILD_TYPE" != "recovery" ]]; then
		log_error "Invalid build type: $BUILD_TYPE (must be 'release' or 'recovery')"
		exit 1
	fi

	check_dependencies

	local version
	version=$(detect_latest_version)

	log_info "Creating output directory: $OUTPUT_DIR"
	mkdir -p "$OUTPUT_DIR"

	local components_url="$BASE_URL/components"
	if [[ "$BUILD_TYPE" == "recovery" ]]; then
		components_url="$BASE_URL/components/recovery"
	fi

	local tarball_name="zfsbootmenu-${BUILD_TYPE}-x86_64-${version}-linux6.12.tar.gz"
	local tarball_path="$OUTPUT_DIR/$tarball_name"

	download_file "$components_url" "$tarball_path" "components tarball"

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
	if ! tar -xzf "$tarball_path" -C "$OUTPUT_DIR"; then
		log_error "Failed to extract tarball"
		exit 1
	fi

	local extract_dir="$OUTPUT_DIR/zfsbootmenu-${BUILD_TYPE}-x86_64-${version}-linux6.12"

	log_info "Extracted to: $extract_dir"

	log_info "Extracted files:"
	ls -lh "$extract_dir"/*

	cd "$OUTPUT_DIR"
	ln -sf "$tarball_name" "zfsbootmenu-latest-${BUILD_TYPE}.tar.gz"
	log_info "Created symlink: zfsbootmenu-latest-${BUILD_TYPE}.tar.gz -> $tarball_name"
	cd - >/dev/null

	log_info "Download complete!"
	log_info "Output directory: $OUTPUT_DIR"
	log_info "Build type: $BUILD_TYPE"
	log_info "Version: $version"
}

main "$@"
