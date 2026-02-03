#!/usr/bin/env bash
# ==============================================================================
# download-zfsbootmenu.sh - Gerenciador de Binários ZFSBootMenu
#
# Baixa e instala os binários do ZFSBootMenu para o projeto de build da ISO.
# Integrado ao debian_trixie_builder-v2.sh
# ==============================================================================

set -euo pipefail

# Cores (compatíveis com o projeto principal)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[38;5;39m'
readonly NC='\033[0m'

# Configuração
readonly BASE_URL="https://get.zfsbootmenu.org"
readonly PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Diretórios de destino (relativos ao projeto)
DEFAULT_DEST_DIR="${PROJECT_DIR}/config/includes.binary/EFI/ZBM"
DEFAULT_SYSLINUX_DIR="${PROJECT_DIR}/config/includes.binary/boot/syslinux/zfsbootmenu"
# Diretório para o instalador (será copiado via includes.chroot)
DEFAULT_INSTALLER_ZBM_DIR="${PROJECT_DIR}/config-overrides/config/includes.chroot/usr/share/zfsbootmenu"

TEMP_DIR=""
DEST_DIR="${DEFAULT_DEST_DIR}"
SYSLINUX_DIR="${DEFAULT_SYSLINUX_DIR}"
INSTALLER_ZBM_DIR="${DEFAULT_INSTALLER_ZBM_DIR}"
FORCE=false
QUIET=false

# Funções de logging
log_info() { [[ ${QUIET} == false ]] && printf "${CYAN}[ZBM]${NC} %s\n" "$*" >&2; }
log_ok() { [[ ${QUIET} == false ]] && printf "${GREEN}[ZBM]${NC} ✔ %s\n" "$*" >&2; }
log_warn() { printf "${YELLOW}[ZBM]${NC} ⚠ %s\n" "$*" >&2; }
log_error() {
	printf "${RED}[ZBM]${NC} ✖ %s\n" "$*" >&2
	exit 1
}
log_step() { [[ ${QUIET} == false ]] && printf "\n${GREEN}==>${NC} ${MAGENTA}%s${NC}\n\n" "$*" >&2; }

cleanup() {
	[[ -n ${TEMP_DIR} ]] && [[ -d ${TEMP_DIR} ]] && rm -rf "${TEMP_DIR}" || true
}
trap cleanup EXIT

show_help() {
	cat <<EOF
${MAGENTA}🌌 ZFSBootMenu Downloader${NC}
${CYAN}Utilitário para download de binários ZFSBootMenu${NC}

${GREEN}Uso:${NC} $0 [OPÇÕES]

${GREEN}Opções:${NC}
  -o, --output-dir DIR     Diretório EFI (Padrão: config/includes.binary/EFI/ZBM)
  -s, --syslinux-dir DIR   Diretório Syslinux (Padrão: config/includes.binary/boot/syslinux/zfsbootmenu)
  -f, --force              Força o download mesmo se arquivos existirem
  -q, --quiet              Modo silencioso
  -h, --help               Exibe esta ajuda

${GREEN}Exemplos:${NC}
  $0                        # Download padrão
  $0 --force               # Força re-download
  $0 -o /custom/path       # Diretório customizado

EOF
	exit 0
}

# Parse argumentos
while [[ $# -gt 0 ]]; do
	case "$1" in
	-o | --output-dir)
		DEST_DIR="$2"
		shift 2
		;;
	-s | --syslinux-dir)
		SYSLINUX_DIR="$2"
		shift 2
		;;
	-f | --force)
		FORCE=true
		shift
		;;
	-q | --quiet)
		QUIET=true
		shift
		;;
	-h | --help)
		show_help
		;;
	*)
		log_error "Opção desconhecida: $1"
		;;
	esac
done

detect_version() {
	# Verificar se há versão definida no .env
	if [[ -n "${ZBM_VERSION:-}" ]] && [[ "${ZBM_VERSION}" != "latest" ]]; then
		log_info "Usando versão definida em ZBM_VERSION: ${ZBM_VERSION}"
		echo "${ZBM_VERSION}"
		return 0
	fi

	log_info "Detectando versão mais recente..."
	local version

	# Método 1: Via redirect
	version=$(curl -sIL "${BASE_URL}/latest" 2>/dev/null | grep -i "location:" | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n 1) || true

	# Método 2: Via API GitHub
	if [[ -z ${version} ]]; then
		version=$(curl -s "https://api.github.com/repos/zbm-dev/zfsbootmenu/releases/latest" 2>/dev/null | grep -oP '"tag_name": "\K[^"]+') || true
	fi

	[[ -z ${version} ]] && log_error "Falha ao detectar versão do ZFSBootMenu."
	log_info "Versão mais recente detectada: ${version}"
	echo "${version}"
}

check_existing() {
	local target_version="$1"
	local version_file="${DEST_DIR}/VERSION"

	# Verifica se já existe instalação completa
	if [[ ${FORCE} == false ]]; then
		if [[ -f "${version_file}" ]] && \
		   [[ -f "${DEST_DIR}/VMLINUZ.EFI" ]] && \
		   [[ -f "${DEST_DIR}/VMLINUZ-RECOVERY.EFI" ]]; then

			# Ler versão instalada
			local installed_version
			installed_version=$(head -n 1 "${version_file}" | awk '{print $2}')
			
			if [[ "${installed_version}" == "${target_version}" ]]; then
				log_ok "ZFSBootMenu já está na versão mais recente (${installed_version}) em ${DEST_DIR}"
				log_info "Use --force para re-baixar"
				return 0
			else
				log_info "Versão instalada (${installed_version}) difere da versão mais recente (${target_version}). Atualizando..."
			fi
		else
			log_info "Instalação não encontrada ou incompleta. Iniciando download..."
		fi
	fi
	return 1
}

fetch_asset_url() {
	local version="$1"
	local type="$2" # release or recovery
	local ext="$3"  # EFI or tar.gz
	
	local pattern="zfsbootmenu-${type}-x86_64-${version}.*\.${ext}"
	
	# Busca URL do asset na API do GitHub
	local url
	url=$(curl -s "https://api.github.com/repos/zbm-dev/zfsbootmenu/releases/tags/${version}" | \
		grep -oP '"browser_download_url": "\K[^"]+' | \
		grep -P "${pattern}" | head -n 1 || true)
		
	echo "${url}"
}

download_efi_binaries() {
	local version="$1"

	log_step "Baixando binários EFI para UEFI (GitHub Releases)..."
	mkdir -p "${DEST_DIR}"

	# Release EFI
	log_info "Buscando URL para VMLINUZ.EFI (release)..."
	local url_release
	url_release=$(fetch_asset_url "${version}" "release" "EFI")
	
	if [[ -n "${url_release}" ]]; then
		log_info "Baixando de: ${url_release}"
		if curl -L -f -s -o "${DEST_DIR}/VMLINUZ.EFI" "${url_release}"; then
			log_ok "VMLINUZ.EFI baixado"
			cp "${DEST_DIR}/VMLINUZ.EFI" "${DEST_DIR}/VMLINUZ-BACKUP.EFI"
		else
			log_warn "Falha ao baixar EFI release"
		fi
	else
		log_error "Asset EFI release não encontrado para versão ${version}"
	fi

	# Recovery EFI
	log_info "Buscando URL para VMLINUZ-RECOVERY.EFI (recovery)..."
	local url_recovery
	url_recovery=$(fetch_asset_url "${version}" "recovery" "EFI")
	
	if [[ -n "${url_recovery}" ]]; then
		log_info "Baixando de: ${url_recovery}"
		if curl -L -f -s -o "${DEST_DIR}/VMLINUZ-RECOVERY.EFI" "${url_recovery}"; then
			log_ok "VMLINUZ-RECOVERY.EFI baixado"
		else
			log_warn "Falha ao baixar EFI recovery"
		fi
	else
		log_error "Asset EFI recovery não encontrado para versão ${version}"
	fi
}

download_syslinux_components() {
	local version="$1"

	log_step "Baixando componentes para BIOS/Syslinux (GitHub Releases)..."
	mkdir -p "${SYSLINUX_DIR}"

	TEMP_DIR=$(mktemp -d)

	local types=("release" "recovery")

	for build_type in "${types[@]}"; do
		log_info "Buscando URL para components ${build_type}..."
		local download_url
		download_url=$(fetch_asset_url "${version}" "${build_type}" "tar.gz")
		
		if [[ -z "${download_url}" ]]; then
			log_warn "Asset tar.gz (${build_type}) não encontrado para versão ${version}"
			continue
		fi

		local tarball
		tarball=$(basename "${download_url}")

		log_info "Baixando ${tarball}..."
		if ! curl -L -f -s -o "${TEMP_DIR}/${tarball}" "${download_url}"; then
			log_warn "Falha ao baixar ${tarball}"
			continue
		fi

		log_info "Extraindo ${build_type}..."
		tar -xzf "${TEMP_DIR}/${tarball}" -C "${TEMP_DIR}"

		local src_dir
		src_dir=$(find "${TEMP_DIR}" -maxdepth 1 -type d -name "zfsbootmenu-*" | head -n 1)

		if [[ -n ${src_dir} ]]; then
			if [[ ${build_type} == "release" ]]; then
				cp "${src_dir}/vmlinuz-bootmenu" "${SYSLINUX_DIR}/" 2>/dev/null || true
				cp "${src_dir}/initramfs-bootmenu.img" "${SYSLINUX_DIR}/" 2>/dev/null || true
			else
				cp "${src_dir}/vmlinuz-bootmenu" "${SYSLINUX_DIR}/vmlinuz-bootmenu-recovery" 2>/dev/null || true
				cp "${src_dir}/initramfs-bootmenu.img" "${SYSLINUX_DIR}/initramfs-bootmenu-recovery.img" 2>/dev/null || true
			fi
			rm -rf "${src_dir}"
		fi
	done
}

create_version_file() {
	local version="$1"

	# Criar arquivo de versão para referência
	cat >"${DEST_DIR}/VERSION" <<EOF
ZFSBootMenu ${version}
Downloaded: $(date -Iseconds)
Source: ${BASE_URL}
EOF

	log_ok "Arquivo de versão criado"
}

show_summary() {
	log_step "Resumo da instalação"

	echo ""
	log_info "Diretório EFI (UEFI):"
	if [[ -d ${DEST_DIR} ]]; then
		ls -lh "${DEST_DIR}" 2>/dev/null | tail -n +2
	fi

	echo ""
	log_info "Diretório Syslinux (BIOS):"
	if [[ -d ${SYSLINUX_DIR} ]]; then
		ls -lh "${SYSLINUX_DIR}" 2>/dev/null | tail -n +2
	fi

	echo ""
	log_ok "ZFSBootMenu instalado com sucesso!"
	log_info "Os binários serão incluídos automaticamente na ISO pelo live-build"
}

main() {
	log_step "ZFSBootMenu Downloader"

	# Verificar dependências
	if ! command -v curl &>/dev/null; then
		log_error "curl não encontrado. Instale com: sudo apt install curl"
	fi

	# Detectar versão
	local version
	version=$(detect_version)
	log_ok "Versão detectada: ${version}"

	# Verificar se já existe e é a mesma versão
	if check_existing "${version}"; then
		return 0
	fi

	# Baixar binários
	download_efi_binaries "${version}"
	download_syslinux_components "${version}"

	# Copiar binários para diretório do instalador (include/)
	log_step "Copiando binários para diretório do instalador..."
	mkdir -p "${INSTALLER_ZBM_DIR}"
	if [[ -f "${DEST_DIR}/VMLINUZ.EFI" ]]; then
		cp -v "${DEST_DIR}/VMLINUZ.EFI" "${INSTALLER_ZBM_DIR}/" 2>/dev/null || true
		cp -v "${DEST_DIR}/VMLINUZ-RECOVERY.EFI" "${INSTALLER_ZBM_DIR}/" 2>/dev/null || true
		log_ok "Binários copiados para ${INSTALLER_ZBM_DIR}"
	fi

	# Criar arquivo de versão
	create_version_file "${version}"

	# Mostrar resumo
	show_summary
}

main "$@"
