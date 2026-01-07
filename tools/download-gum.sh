#!/usr/bin/env bash
#
# download-gum.sh - Baixa o binário estático do gum (charmbracelet)
#

set -euo pipefail

# --- Configurações ---
REPO="charmbracelet/gum"
DEST_DIR="include/usr/local/bin"
TEMP_DIR=""
FORCE=false

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

usage() {
    echo "Uso: $(basename "$0") [--force]"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--force) FORCE=true; shift ;;
        -h|--help) usage ;;
        *) echo "Opção desconhecida: $1"; exit 1 ;;
    esac
done

check_existing() {
    if [[ "$FORCE" == true ]]; then
        return 0
    fi
    if [[ -f "$DEST_DIR/gum" ]]; then
        log_info "Gum já instalado em $DEST_DIR/gum."
        exit 0
    fi
}

main() {
    check_existing

    log_info "Detectando a versão mais recente do gum..."
    local version
    version=$(curl -s https://api.github.com/repos/$REPO/releases/latest | grep -oP '"tag_name": "\K[^"]+')
    
    if [[ -z "$version" ]]; then
        log_error "Não foi possível detectar a versão do gum."
    fi
    
    log_info "Versão detectada: $version"
    
    local clean_version="${version#v}"
    local url="https://github.com/$REPO/releases/download/$version/gum_${clean_version}_Linux_x86_64.tar.gz"
    
    TEMP_DIR=$(mktemp -d)
    log_info "Baixando gum de: $url"
    curl -L -f -s -o "$TEMP_DIR/gum.tar.gz" "$url"
    
    log_info "Extraindo binário..."
    tar -xzf "$TEMP_DIR/gum.tar.gz" -C "$TEMP_DIR"
    
    mkdir -p "$DEST_DIR"
    # O binário geralmente está dentro de uma pasta no tar.gz (ex: gum_0.13.0_Linux_x86_64/gum)
    # Usamos find para localizá-lo independentemente da versão
    local gum_bin
    gum_bin=$(find "$TEMP_DIR" -name "gum" -type f | head -n 1)

    if [[ -n "$gum_bin" ]]; then
        cp "$gum_bin" "$DEST_DIR/gum"
        chmod +x "$DEST_DIR/gum"
        log_info "Gum instalado com sucesso em $DEST_DIR/gum"
    else
        log_error "Binário do gum não encontrado no arquivo baixado."
    fi
}

main "$@"