#!/usr/bin/env bash
#
# download-zfsbootmenu.sh
#
# Baixa os binários release do ZFSBootMenu e os instala diretamente na
# estrutura de inclusão da ISO (include/usr/share/zfsbootmenu).
#

set -euo pipefail

# --- Configuração ---
BASE_URL="https://get.zfsbootmenu.org"
# Destino final dentro da estrutura do projeto
DEST_DIR="include/usr/share/zfsbootmenu"
BUILD_TYPE="release"
VERIFY_SIGNATURES=false
TEMP_DIR=""

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

usage() {
    cat <<EOF
Uso: $(basename "$0") [OPÇÕES]

Baixa binários do ZFSBootMenu e instala em $DEST_DIR

OPÇÕES:
    -o, --output-dir DIR     Diretório de destino (padrão: $DEST_DIR)
    -b, --build-type TYPE    Tipo de build: release ou recovery (padrão: release)
    -v, --verify             Verificar assinaturas GPG (requer gpg)
    -f, --force              Forçar download mesmo se arquivos já existirem
    -h, --help               Mostra esta ajuda
EOF
    exit 1
}

FORCE=false

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
    -h | --help)
        usage
        ;;
    *)
        log_error "Opção desconhecida: $1"
        ;;
    esac
done

check_existing() {
    if [[ "$FORCE" == true ]]; then
        return 0
    fi

    if [[ -f "$DEST_DIR/vmlinuz-bootmenu" && -f "$DEST_DIR/initramfs-bootmenu.img" ]]; then
        log_info "Arquivos do ZFSBootMenu já existem em $DEST_DIR."
        log_info "Use --force para baixar novamente."
        exit 0
    fi
}

detect_latest_version() {
    log_info "Detectando versão mais recente do ZFSBootMenu..."
    local version
    version=$(curl -sIL "$BASE_URL/latest" | grep -i "location:" | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    if [[ -z "$version" ]]; then
        version=$(curl -s https://api.github.com/repos/zbm-dev/zfsbootmenu/releases/latest | grep -oP '"tag_name": "\K[^"]+')
    fi

    if [[ -z "$version" ]]; then
        log_error "Falha ao detectar versão."
    fi
    echo "$version"
}

download_file() {
    local url="$1"
    local dest="$2"
    log_info "Baixando $(basename "$dest")..."
    curl -L -f -s -o "$dest" "$url"
}

main() {
    check_existing

    local version
    version=$(detect_latest_version)
    log_info "Versão detectada: $version"

    # Cria diretório temporário para download e extração
    TEMP_DIR=$(mktemp -d)
    
    # URL do tarball
    local tarball_url="$BASE_URL/components"
    if [[ "$BUILD_TYPE" == "recovery" ]]; then
        tarball_url="$BASE_URL/components/recovery"
    fi

    # Nome do arquivo (tentativa de inferir)
    local tarball_name="zfsbootmenu-${BUILD_TYPE}-x86_64-${version}.tar.gz"
    local tarball_path="$TEMP_DIR/$tarball_name"

    download_file "$tarball_url" "$tarball_path"

    if [[ "$VERIFY_SIGNATURES" == true ]]; then
        local checksum_path="$TEMP_DIR/sha256.txt"
        local sig_path="$TEMP_DIR/sha256.sig"
        download_file "$BASE_URL/sha256.txt" "$checksum_path"
        download_file "$BASE_URL/sha256.sig" "$sig_path"
        
        # Lógica de verificação simplificada (requer chave pública importada previamente em um cenário real robusto)
        if command -v gpg >/dev/null; then
             log_info "Verificando assinatura (checksum)..."
             if gpg --verify "$sig_path" "$checksum_path" 2>/dev/null; then
                 log_info "Assinatura OK."
             else
                 log_warn "Falha na verificação da assinatura GPG (ou chave pública ausente)."
             fi
             log_info "Verificando SHA256 do arquivo..."
             cd "$TEMP_DIR"
             if grep "$tarball_name" sha256.txt | sha256sum --check --ignore-missing --status; then
                 log_info "Checksum validado com sucesso."
             else
                 log_error "Checksum inválido!"
             fi
             cd - >/dev/null
        else
            log_warn "GPG não encontrado, pulando verificação."
        fi
    fi

    log_info "Extraindo arquivos..."
    tar -xzf "$tarball_path" -C "$TEMP_DIR"

    # Localiza o diretório extraído
    local source_dir
    source_dir=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "zfsbootmenu-release-*" | head -n 1)

    if [[ -z "$source_dir" ]]; then
        log_error "Falha ao encontrar diretório extraído."
    fi

    log_info "Instalando binários em: $DEST_DIR"
    mkdir -p "$DEST_DIR"

    # Copia arquivos essenciais e achata a estrutura
    cp -v "$source_dir/vmlinuz-bootmenu" "$DEST_DIR/"
    cp -v "$source_dir/initramfs-bootmenu.img" "$DEST_DIR/"
    # Copia componentes UEFI se existirem
    find "$source_dir" -name "*.EFI" -exec cp -v {} "$DEST_DIR/" \;

    log_info "Instalação concluída com sucesso."
}

main "$@"
