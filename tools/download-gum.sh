#!/usr/bin/env bash
# ==============================================================================
# download-gum.sh - Gerenciador de Binários Gum
#
# Baixa e instala a versão mais recente do gum (charmbracelet).
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

# Configurações
readonly REPO="charmbracelet/gum"
readonly DEST_DIR="include/usr/local/bin"
TEMP_DIR=$(mktemp -d)
readonly TEMP_DIR
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
	[[ -d ${TEMP_DIR} ]] && rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

function show_help() {
	cat <<EOF
${C_BOLD}${C_PURPLE}🌌 AURORA OS - GUM DOWNLOADER${C_RESET}
${C_CYAN}Utilitário para instalação do binário gum${C_RESET}

${C_BOLD}Uso:${C_RESET} \$0 ${C_GREEN}[OPÇÃO]${C_RESET}

${C_BOLD}Opções:${C_RESET}
  ${C_GREEN}-f, --force${C_RESET}    Força o download mesmo se já instalado
  ${C_GREEN}-h, --help${C_RESET}     Exibe esta interface de ajuda

${C_PURPLE}Destino:${C_RESET} ${DEST_DIR}/gum
EOF
	exit 0
}

# Parse de argumentos
while [[ $# -gt 0 ]]; do
	case "$1" in
	-f | --force)
		FORCE=true
		shift
		;;
	-h | --help) show_help ;;
	*) log_error "Opção desconhecida: $1" ;;
	esac
done

function main() {
	if [[ ${FORCE} == false ]] && [[ -f "${DEST_DIR}/gum" ]]; then
		log_ok "Gum já está instalado em ${DEST_DIR}/gum."
		return 0
	fi

	log_info "Detectando a versão mais recente do gum..."
	local version
	version=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" | grep -oP '"tag_name": "\K[^"]+') || log_error "Não foi possível detectar a versão."

	log_info "Versão detectada: ${version}"

	local clean_version="${version#v}"
	local url="https://github.com/${REPO}/releases/download/${version}/gum_${clean_version}_Linux_x86_64.tar.gz"

	log_info "Baixando release..."
	if ! curl -L -f -s -o "${TEMP_DIR}/gum.tar.gz" "${url}"; then
		log_error "Falha no download da URL: ${url}"
	fi

	log_info "Extraindo e instalando..."
	tar -xzf "${TEMP_DIR}/gum.tar.gz" -C "${TEMP_DIR}"

	mkdir -p "${DEST_DIR}"
	local gum_bin
	gum_bin=$(find "${TEMP_DIR}" -name "gum" -type f | head -n 1)

	if [[ -n ${gum_bin} ]]; then
		cp "${gum_bin}" "${DEST_DIR}/gum"
		chmod +x "${DEST_DIR}/gum"
		log_ok "Gum instalado com sucesso em ${DEST_DIR}/gum"
	else
		log_error "Binário do gum não encontrado no pacote baixado."
	fi
}

main
