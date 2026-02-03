#!/usr/bin/env bash
#
# download-zfsbootmenu.sh - Download ZFSBootMenu binaries for live-build integration
#

set -euo pipefail

# --- Configuration ---
# Base destination for live-build binary inclusion
TARGET_BINARY_DIR="config-overrides/config/includes.binary"

# Directories for specific components
ZBM_BIOS_DIR="${TARGET_BINARY_DIR}/zbm"
EFI_BOOT_DIR="${TARGET_BINARY_DIR}/EFI/BOOT"

BASE_URL="https://get.zfsbootmenu.org"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[INFO]${NC} $*" >&2; }
log_step() { echo -e "${BLUE}[STEP]${NC} $*" >&2; }

detect_latest_version() {
    log "Detecting latest ZFSBootMenu version..."
    # Try getting version from redirect
    local version
    version=$(curl -sIL "${BASE_URL}/latest" | grep -i "location:" | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    
    # Fallback to GitHub API if redirect fails
    if [[ -z "$version" ]]; then
        version=$(curl -s https://api.github.com/repos/zbm-dev/zfsbootmenu/releases/latest | grep -oP '"tag_name": "\K[^"]+')
    fi

    if [[ -z "$version" ]]; then
        echo "Error: Could not detect ZFSBootMenu version." >&2
        exit 1
    fi
    echo "$version"
}

main() {
    local version
    version=$(detect_latest_version)
    log "Latest version: ${version}"

    # 1. Prepare directories
    log_step "Creating directory structure..."
    mkdir -p "${ZBM_BIOS_DIR}"
    mkdir -p "${EFI_BOOT_DIR}"

    # Fetch release info once
    local release_json
    release_json=$(curl -s https://api.github.com/repos/zbm-dev/zfsbootmenu/releases/latest)

    # Function to extract URL for a specific pattern, sorting to get the latest kernel
    get_asset_url() {
        local pattern="$1"
        echo "$release_json" | grep "browser_download_url" | cut -d '"' -f 4 | grep -E "$pattern" | sort -V | tail -n 1
    }

    # 2. Download EFI Executable (UEFI Boot)
    log_step "Downloading EFI executable..."
    # Pattern to match release EFI with kernel version
    local efi_url
    efi_url=$(get_asset_url "zfsbootmenu-release-x86_64-${version}-linux.*\.EFI")
    
    if [[ -z "$efi_url" ]]; then
        echo "Error: Could not find EFI asset URL." >&2
        exit 1
    fi

    local efi_dest="${EFI_BOOT_DIR}/BOOTX64.EFI"
    
    log "Downloading ${efi_url} -> ${efi_dest}"
    curl -L -f -o "${efi_dest}" "${efi_url}"

    # 3. Download BIOS Components (Kernel + Initramfs)
    log_step "Downloading BIOS components..."
    local vmlinuz_url
    vmlinuz_url=$(get_asset_url "zfsbootmenu-release-x86_64-${version}-linux.*\.tar.gz")

    if [[ -z "$vmlinuz_url" ]]; then
        echo "Error: Could not find components tarball URL." >&2
        exit 1
    fi
    # Note: We need to extract the tarball to get vmlinuz and initramfs
    
    # Global temp_dir for trap access
    temp_dir=$(mktemp -d)
    trap 'rm -rf "${temp_dir}"' EXIT

    log "Downloading tarball to temporary location..."
    curl -L -f -o "${temp_dir}/zbm.tar.gz" "${vmlinuz_url}"
    
    log "Extracting components..."
    tar -xzf "${temp_dir}/zbm.tar.gz" -C "${temp_dir}"
    
    # Locate extracted files (folder name may vary slightly)
    local extract_root
    extract_root=$(find "${temp_dir}" -maxdepth 1 -type d -name "zfsbootmenu-*" | head -n 1)

    if [[ -d "$extract_root" ]]; then
        log "Copying vmlinuz and initramfs to ${ZBM_BIOS_DIR}..."
        cp -v "${extract_root}/vmlinuz-bootmenu" "${ZBM_BIOS_DIR}/vmlinuz"
        cp -v "${extract_root}/initramfs-bootmenu.img" "${ZBM_BIOS_DIR}/initramfs.img"
    else
        echo "Error: Could not find extracted directory in ${temp_dir}" >&2
        exit 1
    fi

    log "✅ ZFSBootMenu binaries successfully placed."
    log "   UEFI: ${EFI_BOOT_DIR}/BOOTX64.EFI"
    log "   BIOS: ${ZBM_BIOS_DIR}/{vmlinuz,initramfs.img}"
}

main "$@"