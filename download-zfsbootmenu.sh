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
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Diretórios de destino (relativos ao projeto)
DEFAULT_DEST_DIR="${SCRIPT_DIR}/config/includes.binary/EFI/ZBM"
DEFAULT_SYSLINUX_DIR="${SCRIPT_DIR}/config/includes.binary/boot/syslinux/zfsbootmenu"
# Diretório para o instalador (será copiado via includes.chroot)
DEFAULT_INSTALLER_ZBM_DIR="${SCRIPT_DIR}/include/usr/share/zfsbootmenu"

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
	[[ -n ${TEMP_DIR} ]] && [[ -d ${TEMP_DIR} ]] && rm -rf "${TEMP_DIR}"
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
	log_info "Detectando versão mais recente..."
	local version

	# Método 1: Via redirect
	version=$(curl -sIL "${BASE_URL}/latest" 2>/dev/null | grep -i "location:" | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n 1) || true

	# Método 2: Via API GitHub
	if [[ -z ${version} ]]; then
		version=$(curl -s "https://api.github.com/repos/zbm-dev/zfsbootmenu/releases/latest" 2>/dev/null | grep -oP '"tag_name": "\K[^"]+') || true
	fi

	[[ -z ${version} ]] && log_error "Falha ao detectar versão do ZFSBootMenu."
	echo "${version}"
}

check_existing() {
	# Verifica se já existe instalação completa
	if [[ ${FORCE} == false ]]; then
		if [[ -f "${DEST_DIR}/VMLINUZ.EFI" ]] && [[ -f "${DEST_DIR}/VMLINUZ-RECOVERY.EFI" ]]; then
			log_ok "ZFSBootMenu já instalado em ${DEST_DIR}"
			log_info "Use --force para re-baixar"
			return 0
		fi
	fi
	return 1
}

download_efi_binaries() {
	local version="$1"

	log_step "Baixando binários EFI para UEFI..."
	mkdir -p "${DEST_DIR}"

	# Binário EFI principal (release)
	log_info "Baixando VMLINUZ.EFI (release)..."
	if curl -L -f -s -o "${DEST_DIR}/VMLINUZ.EFI" "${BASE_URL}/efi"; then
		log_ok "VMLINUZ.EFI baixado"
		# Criar backup
		cp "${DEST_DIR}/VMLINUZ.EFI" "${DEST_DIR}/VMLINUZ-BACKUP.EFI"
	else
		log_warn "Falha ao baixar EFI release"
	fi

	# Binário EFI recovery
	log_info "Baixando VMLINUZ-RECOVERY.EFI..."
	if curl -L -f -s -o "${DEST_DIR}/VMLINUZ-RECOVERY.EFI" "${BASE_URL}/efi/recovery"; then
		log_ok "VMLINUZ-RECOVERY.EFI baixado"
	else
		log_warn "Falha ao baixar EFI recovery"
	fi
}

download_syslinux_components() {
	local version="$1"

	log_step "Baixando componentes para BIOS/Syslinux..."
	mkdir -p "${SYSLINUX_DIR}"

	TEMP_DIR=$(mktemp -d)

	local types=("release" "recovery")

	for build_type in "${types[@]}"; do
		local build_url="${BASE_URL}/components"
		[[ ${build_type} == "recovery" ]] && build_url="${BASE_URL}/components/recovery"

		local tarball="zfsbootmenu-${build_type}-x86_64-${version}.tar.gz"

		log_info "Baixando ${tarball}..."
		if ! curl -L -f -s -o "${TEMP_DIR}/${tarball}" "${build_url}"; then
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

	# Verificar se já existe
	if check_existing; then
		return 0
	fi

	# Verificar dependências
	if ! command -v curl &>/dev/null; then
		log_error "curl não encontrado. Instale com: sudo apt install curl"
	fi

	# Detectar versão
	local version
	version=$(detect_version)
	log_ok "Versão detectada: ${version}"

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
