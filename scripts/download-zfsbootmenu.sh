#!/usr/bin/env bash
# =============================================================================
# @DEV_SCRIPT: download-zfsbootmenu - Baixa binários do ZFSBootMenu
# @DEV_CATEGORY: build
# @DEV_MAKEFILE: download-zbm
# @DEV_DEP: curl, tar, grep, awk
# @DEV_OUTPUT: config-overrides/config/includes.binary/EFI/BOOT/BOOTX64.EFI
# @DEV_OUTPUT: config-overrides/config/includes.binary/zbm/vmlinuz
# @DEV_OUTPUT: config-overrides/config/includes.binary/zbm/initramfs.img
# =============================================================================
# Download ZFSBootMenu binaries for live-build integration
# Detecta automaticamente a versão mais recente via GitHub API e baixa:
# - EFI executable para boot UEFI (BOOTX64.EFI)
# - Kernel + initramfs para boot BIOS (vmlinuz, initramfs.img)
# =============================================================================

set -euo pipefail

# --- Logging Configuration ---
LOG_DIR="logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/download-zfsbootmenu.log"

# Redirect all output to log file and stdout
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "================================================================================"
echo "Run started at: $(date --iso-8601=seconds)"
echo "================================================================================"

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

# @DEV_FUNC: log - Exibe mensagem informativa
log() { echo -e "${GREEN}[INFO]${NC} $*" >&2; }

# @DEV_FUNC: log_step - Exibe etapa do processo
log_step() { echo -e "${BLUE}[STEP]${NC} $*" >&2; }

# -----------------------------------------------------------------------------
# @DEV_FUNC: detect_latest_version - Detecta versão mais recente do ZFSBootMenu
# @DEV_INPUT: Nenhum (usa API GitHub)
# @DEV_OUTPUT: String com versão (ex: v2.3.0) via stdout
# @DEV_TODO: Adicionar cache local para evitar rate-limit da API
# -----------------------------------------------------------------------------
detect_latest_version() {
	log "Detecting latest ZFSBootMenu version..."
	# Try getting version from redirect
	local version
	version=$(curl --retry 3 --retry-delay 5 -sIL "${BASE_URL}/latest" | grep -i "location:" | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)

	# Fallback to GitHub API if redirect fails
	if [[ -z "$version" ]]; then
		version=$(curl --retry 3 --retry-delay 5 -s https://api.github.com/repos/zbm-dev/zfsbootmenu/releases/latest | grep -oP '"tag_name": "\K[^"]+')
	fi

	if [[ -z "$version" ]]; then
		echo "Error: Could not detect ZFSBootMenu version." >&2
		exit 1
	fi
	echo "$version"
}

# -----------------------------------------------------------------------------
# @DEV_FUNC: main - Orquestra download de todos os componentes ZBM
# @DEV_INPUT: Nenhum argumento requerido
# @DEV_OUTPUT: Arquivos em config-overrides/config/includes.binary/
# -----------------------------------------------------------------------------
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
	release_json=$(curl --retry 3 --retry-delay 5 -s https://api.github.com/repos/zbm-dev/zfsbootmenu/releases/latest)

	# @DEV_FUNC: get_asset_url - Extrai URL de asset do release JSON
	# @DEV_INPUT: $1=pattern (regex para filtrar assets)
	# @DEV_OUTPUT: URL do asset via stdout
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
	curl --retry 3 --retry-delay 5 -L -f -o "${efi_dest}" "${efi_url}"

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
	curl --retry 3 --retry-delay 5 -L -f -o "${temp_dir}/zbm.tar.gz" "${vmlinuz_url}"

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
