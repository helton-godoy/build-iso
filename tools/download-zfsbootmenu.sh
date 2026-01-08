#!/usr/bin/env bash
# ==============================================================================
# download-zfsbootmenu.sh - Gerenciador de Binários ZFSBootMenu
#
# Baixa e instala os binários do ZFSBootMenu na estrutura do projeto.
# ==============================================================================

set -euo pipefail

# Cores e Estilos (ANSI)
readonly C_RESET=$'\033[0m'
readonly C_BOLD=$'\033[1m'
readonly C_PURPLE=$'\033[38;5;105m'
readonly C_CYAN=$'\033[38;5;39m'
readonly C_GREEN=$'\033[32m'
readonly C_YELLOW=$'\033[33m'
readonly C_RED=$'\033[31m'

# Configuração
readonly BASE_URL="https://get.zfsbootmenu.org"
readonly TEMP_DIR=$(mktemp -d)
DEST_DIR="include/usr/share/zfsbootmenu"
BUILD_TYPE="release"
VERIFY_SIGNATURES=false
FORCE=false

# Funções de logging
log_info() { printf "${C_CYAN}ℹ %s${C_RESET}\n" "$*"; }
log_ok() { printf "${C_GREEN}✔ %s${C_RESET}\n" "$*"; }
log_warn() { printf "${C_YELLOW}⚠ %s${C_RESET}\n" "$*"; }
log_error() {
	printf "${C_RED}${C_BOLD}✖ %s${C_RESET}\n" "$*"
	exit 1
}

function cleanup() {
	[[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

function show_help() {
	cat <<EOF
${C_BOLD}${C_PURPLE}🌌 AURORA OS - ZFSBOOTMENU DOWNLOADER${C_RESET}
${C_CYAN}Utilitário para instalação de binários ZFSBootMenu${C_RESET}

${C_BOLD}Uso:${C_RESET} \$0 ${C_GREEN}[OPÇÕES]${C_RESET}

${C_BOLD}Opções:${C_RESET}
  ${C_GREEN}-o, --output-dir DIR${C_RESET}   Diretório de destino (Padrão: ${DEST_DIR})
  ${C_GREEN}-b, --build-type TYPE${C_RESET}  Tipo: release ou recovery (Padrão: release)
  ${C_GREEN}-v, --verify${C_RESET}           Verifica assinaturas GPG
  ${C_GREEN}-f, --force${C_RESET}            Força o download
  ${C_GREEN}-h, --help${C_RESET}             Exibe esta ajuda
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
	-b | --build-type)
		BUILD_TYPE="$2"
		shift 2
		;;
	-v | --verify)
		VERIFY_SIGNATURES=true
		shift
		;;
	-f | --force)
		FORCE=true
		shift
		;;
	-h | --help) show_help ;;
	*) log_error "Opção desconhecida: $1" ;;
	esac
done

function detect_version() {
	log_info "Detectando versão mais recente..."
	local version
	version=$(curl -sIL "$BASE_URL/latest" | grep -i "location:" | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n 1) ||
		version=$(curl -s "https://api.github.com/repos/zbm-dev/zfsbootmenu/releases/latest" | grep -oP '"tag_name": "\K[^"]+')

	[[ -z "$version" ]] && log_error "Falha ao detectar versão."
	echo "$version"
}

function main() {
	# Verificar se já existe (pular se não forçado)
	if [[ "$FORCE" == false ]] && [[ -f "$DEST_DIR/VMLINUZ.EFI" ]] && [[ -f "$DEST_DIR/VMLINUZ-RECOVERY.EFI" ]]; then
		log_ok "ZFSBootMenu (release + recovery) já instalado em $DEST_DIR."
		return 0
	fi

	local version
	version=$(detect_version)
	log_info "Versão: $version"

	mkdir -p "$DEST_DIR"

	# Baixar ambos os tipos: release e recovery
	local types=("release" "recovery")

	for build_type in "${types[@]}"; do
		local build_url="$BASE_URL/components"
		[[ "$build_type" == "recovery" ]] && build_url="$BASE_URL/components/recovery"

		local tarball="zfsbootmenu-${build_type}-x86_64-${version}.tar.gz"

		log_info "Baixando $tarball..."
		if ! curl -L -f -s -o "$TEMP_DIR/$tarball" "$build_url"; then
			log_warn "Falha ao baixar $tarball"
			continue
		fi

		log_info "Extraindo $build_type..."
		tar -xzf "$TEMP_DIR/$tarball" -C "$TEMP_DIR"

		local src_dir
		src_dir=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "zfsbootmenu-*" | head -n 1)

		if [[ -n "$src_dir" ]]; then
			# Copiar componentes com sufixo se for recovery
			if [[ "$build_type" == "release" ]]; then
				cp "$src_dir/vmlinuz-bootmenu" "$DEST_DIR/" 2>/dev/null || true
				cp "$src_dir/initramfs-bootmenu.img" "$DEST_DIR/" 2>/dev/null || true
			else
				cp "$src_dir/vmlinuz-bootmenu" "$DEST_DIR/vmlinuz-bootmenu-recovery" 2>/dev/null || true
				cp "$src_dir/initramfs-bootmenu.img" "$DEST_DIR/initramfs-bootmenu-recovery.img" 2>/dev/null || true
			fi
			find "$src_dir" -name "*.EFI" -exec cp {} "$DEST_DIR/" \; 2>/dev/null || true
			rm -rf "$src_dir"
		fi
	done

	# Baixar binários EFI unificados (release e recovery)
	log_info "Baixando binário EFI release..."
	if curl -L -f -s -o "$DEST_DIR/VMLINUZ.EFI" "$BASE_URL/efi"; then
		log_ok "Binário EFI release: VMLINUZ.EFI"
		# Criar backup
		cp "$DEST_DIR/VMLINUZ.EFI" "$DEST_DIR/VMLINUZ-BACKUP.EFI" 2>/dev/null || true
	else
		log_warn "Falha ao baixar EFI release"
	fi

	log_info "Baixando binário EFI recovery..."
	if curl -L -f -s -o "$DEST_DIR/VMLINUZ-RECOVERY.EFI" "$BASE_URL/efi/recovery"; then
		log_ok "Binário EFI recovery: VMLINUZ-RECOVERY.EFI"
	else
		log_warn "Falha ao baixar EFI recovery"
	fi

	log_ok "ZFSBootMenu instalado com sucesso em $DEST_DIR"
	log_info "Conteúdo:"
	ls -lh "$DEST_DIR"
}

main
