#!/bin/bash
# =============================================================================
# setup_host.sh - Configura o host para virtualização KVM/libvirt
# Versão compatível com Deepin 25
# =============================================================================

set -euo pipefail

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERRO]${NC} $*" >&2; }

# =============================================================================
# VERIFICAÇÕES
# =============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Execute como root: sudo $0"
        exit 1
    fi
}

check_virtualization() {
    log_info "Verificando suporte a virtualização..."
    
    if grep -qE '(vmx|svm)' /proc/cpuinfo; then
        log_ok "CPU suporta virtualização"
    else
        log_error "CPU não suporta virtualização (VT-x/AMD-V)"
        exit 1
    fi
    
    if [[ -c /dev/kvm ]]; then
        log_ok "KVM disponível"
    else
        log_warn "/dev/kvm não encontrado. Será criado após instalação."
    fi
}

# =============================================================================
# INSTALAÇÃO
# =============================================================================

install_packages() {
    log_info "Instalando pacotes de virtualização..."
    
    apt-get update -qq
    
    # Pacotes disponíveis no Deepin 25
    local packages=(
        # KVM/QEMU
        qemu-system-x86
        qemu-utils
        
        # Libvirt
        libvirt-daemon-system
        libvirt-clients
        
        # Ferramentas
        virtinst
        cloud-image-utils
        
        # Rede
        bridge-utils
        dnsmasq-base
        
        # Utilitários
        jq
        curl
        wget
        genisoimage
    )
    
    # Instalar apenas pacotes disponíveis
    for pkg in "${packages[@]}"; do
        if apt-cache show "$pkg" &>/dev/null; then
            apt-get install -y "$pkg" || log_warn "Falha ao instalar $pkg"
        else
            log_warn "Pacote não disponível: $pkg"
        fi
    done
    
    log_ok "Pacotes instalados"
}

configure_libvirt() {
    log_info "Configurando libvirt..."
    
    # Habilitar e iniciar serviço
    systemctl enable --now libvirtd
    
    # Adicionar usuário atual ao grupo libvirt
    local current_user="${SUDO_USER:-$USER}"
    usermod -aG libvirt "$current_user" 2>/dev/null || true
    usermod -aG kvm "$current_user" 2>/dev/null || true
    
    # Configurar rede padrão
    if ! virsh net-info default &>/dev/null; then
        log_info "Criando rede virtual padrão..."
        virsh net-define /usr/share/libvirt/networks/default.xml 2>/dev/null || true
    fi
    
    virsh net-autostart default 2>/dev/null || true
    virsh net-start default 2>/dev/null || true
    
    log_ok "Libvirt configurado"
}

configure_directories() {
    log_info "Configurando diretórios..."
    
    local project_dir="/home/${SUDO_USER:-$USER}/git/ISO/build-iso"
    
    mkdir -p "$project_dir"/{output,logs,images}
    chown -R "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$project_dir"
    
    log_ok "Diretórios configurados"
}

verify_installation() {
    log_info "Verificando instalação..."
    
    local errors=0
    
    # Verificar serviço
    if systemctl is-active --quiet libvirtd; then
        log_ok "libvirtd está ativo"
    else
        log_error "libvirtd não está ativo"
        ((errors++))
    fi
    
    # Verificar comandos essenciais
    for cmd in virsh virt-install qemu-img; do
        if command -v "$cmd" &>/dev/null; then
            log_ok "$cmd disponível"
        else
            log_error "$cmd não encontrado"
            ((errors++))
        fi
    done
    
    if [[ $errors -eq 0 ]]; then
        log_ok "Instalação verificada com sucesso!"
    else
        log_error "Encontrados $errors erros na verificação"
        exit 1
    fi
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    echo "============================================="
    echo " Setup do Host (Deepin 25 Compatível)"
    echo "============================================="
    
    check_root
    check_virtualization
    install_packages
    configure_libvirt
    configure_directories
    verify_installation
    
    echo ""
    log_ok "Host configurado com sucesso!"
    log_info "Faça logout e login para aplicar permissões de grupo."
}

main "$@"
