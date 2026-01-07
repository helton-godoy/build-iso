#!/usr/bin/env bash
#
# download-gum.sh - Baixa o binário estático do gum (charmbracelet)
#

set -euo pipefail

# --- Configurações ---
REPO="charmbracelet/gum"
DEST_DIR="$(pwd)/config/includes.chroot/usr/local/bin"
TEMP_DIR="/tmp/gum-download"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

main() {
    log_info "Detectando a versão mais recente do gum..."
    local version
    version=$(curl -s https://api.github.com/repos/$REPO/releases/latest | grep -oP '"tag_name": "\K[^"]+')
    
    if [[ -z "$version" ]]; then
        log_error "Não foi possível detectar a versão do gum."
    fi
    
    log_info "Versão detectada: $version"
    
    local clean_version="${version#v}"
    local url="https://github.com/$REPO/releases/download/$version/gum_${clean_version}_Linux_x86_64.tar.gz"
    
    log_info "Baixando gum de: $url"
    mkdir -p "$TEMP_DIR"
    curl -L -f -o "$TEMP_DIR/gum.tar.gz" "$url"
    
    log_info "Extraindo binário..."
    tar -xzf "$TEMP_DIR/gum.tar.gz" -C "$TEMP_DIR"
    
    mkdir -p "$DEST_DIR"
    # O binário está dentro de uma pasta no tar.gz
    cp "$TEMP_DIR"/gum_*/gum "$DEST_DIR/gum"
    chmod +x "$DEST_DIR/gum"
    
    log_info "Limpando arquivos temporários..."
    rm -rf "$TEMP_DIR"
    
    log_info "Gum instalado com sucesso em $DEST_DIR/gum"
}

main "$@"
