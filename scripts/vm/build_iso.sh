#!/bin/bash
# =============================================================================
# build_iso.sh - Gera ISO Debian com perfis Server/Workstation
# Executa DENTRO da VM de build
# =============================================================================

set -euo pipefail

# Configurações
BUILD_DIR="/root/build-iso/output/live-build"
OUTPUT_DIR="/root/build-iso/output/ISO"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
ISO_NAME="debian-zfs-${TIMESTAMP}.iso"

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
# CONFIGURAÇÃO DO LIVE-BUILD
# =============================================================================

setup_build_env() {
    log_info "Configurando ambiente de build..."
    
    # Limpar build anterior
    rm -rf "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"
    cd "${BUILD_DIR}"
    
    log_ok "Ambiente preparado"
}

configure_live_build() {
    log_info "Configurando live-build..."
    
    lb config \
        --binary-images iso-hybrid \
        --mode debian \
        --distribution trixie \
        --archive-areas "main contrib non-free non-free-firmware" \
        --updates true \
        --security true \
        --backports false \
        --apt-recommends false \
        --apt-indices false \
        --memtest none \
        --bootappend-live "boot=live components quiet splash locales=pt_BR.UTF-8 username=live user-fullname=User hostname=Debian13 autologin" \
        --debian-installer live \
        --debian-installer-gui true \
        --iso-application "Debian-ZFS-ISO" \
        --iso-publisher "Helton Godoy" \
        --iso-volume "Debian-ZFS-${TIMESTAMP}"
    
    log_ok "live-build configurado"
}

# =============================================================================
# PACOTES BASE (comum a ambos perfis)
# =============================================================================

add_base_packages() {
    log_info "Adicionando pacotes base..."

    mkdir -p config/package-lists

    cat > config/package-lists/base.list.chroot << 'EOF'
# ======================
# PACOTES BASE (Comum)
# ======================

# ZFS
zfsutils-linux
zfs-dkms
zfs-initramfs

# Kernel e build
linux-image-amd64
linux-headers-amd64
dkms

# Rede
network-manager
openssh-server
curl
wget

# Ferramentas essenciais
vim
nano
htop
tmux
git
rsync

# Compressão
zstd
lz4

# Particionamento
gdisk
parted
dosfstools
efibootmgr

# Locale
locales
console-setup

# Firmware
firmware-linux-free
EOF

    log_ok "Pacotes base adicionados"
}

# =============================================================================
# PACOTES SERVIDOR
# =============================================================================

add_server_packages() {
    log_info "Adicionando pacotes Server..."

    cat > config/package-lists/server.list.chroot << 'EOF'
# ======================
# PERFIL SERVER
# Modo texto, headless
# ======================

# Monitoramento
iotop
iftop
nmon
glances

# Administração
sudo
screen
mc
ncdu
tree

# Logs
logrotate
rsyslog

# Segurança
fail2ban
ufw

# NFS/SMB (opcional)
nfs-common
cifs-utils
EOF

    log_ok "Pacotes Server adicionados"
}

# =============================================================================
# PACOTES WORKSTATION
# =============================================================================

add_workstation_packages() {
    log_info "Adicionando pacotes Workstation (KDE Plasma)..."

    cat > config/package-lists/workstation.list.chroot << 'EOF'
# ================================
# PERFIL WORKSTATION
# KDE Plasma Minimalista (Qt only)
# ================================

# Core Plasma
plasma-desktop
plasma-workspace
sddm
sddm-theme-breeze

# Componentes Plasma
kwin-x11
plasma-nm
plasma-pa
powerdevil
bluedevil

# Gerenciador de arquivos
dolphin
dolphin-plugins

# Terminal
konsole

# Editor de texto
kate

# Navegador
firefox-esr

# Visualizador de imagens
gwenview

# Utilitários Qt
ark
kcalc
partitionmanager

# Configurações
systemsettings

# Áudio
pipewire
pipewire-pulse
wireplumber

# Fontes
fonts-noto
fonts-noto-color-emoji

# Tema
breeze
breeze-icon-theme
breeze-cursor-theme

# Widgets
plasma-widgets-addons
EOF

    log_ok "Pacotes Workstation adicionados"
}

# =============================================================================
# CALAMARES (Instalador)
# =============================================================================

add_calamares() {
    log_info "Adicionando Calamares..."
    
    cat > config/package-lists/calamares.list.chroot << 'EOF'
# Instalador
calamares
calamares-settings-debian

# Dependências
os-prober
cryptsetup
kpartx
EOF

    log_ok "Calamares adicionado"
}

# =============================================================================
# HOOKS DE CONFIGURAÇÃO
# =============================================================================

# =============================================================================
# ZFSBOOTMENU
# =============================================================================

prepare_zfsbootmenu() {
    log_info "Preparando ZFSBootMenu..."
    
    local zbm_dir="config/includes.chroot/usr/share/zfsbootmenu"
    mkdir -p "${zbm_dir}"
    
    # Download do ZFSBootMenu EFI (Release estável)
    # Usaremos x86_64 vmlinuz.EFI
    local zbm_url="https://github.com/zbm-dev/zfsbootmenu/releases/latest/download/zfsbootmenu-x86_64-vmlinuz.EFI"
    
    if curl -L -o "${zbm_dir}/zfsbootmenu.EFI" "${zbm_url}"; then
        log_ok "ZFSBootMenu EFI baixado com sucesso"
    else
        log_warn "Falha ao baixar ZFSBootMenu. O instalador precisará baixar durante o processo."
    fi
}

add_hooks() {
    log_info "Adicionando hooks de configuração..."
    
    mkdir -p config/hooks/normal
    
    # Hook ZFS
    cat > config/hooks/normal/0100-setup-zfs.hook.chroot << 'ZFSHOOK'
#!/bin/bash
set -e
echo "Configurando ZFS..."

# Garantir repos
if ! grep -q "contrib" /etc/apt/sources.list 2>/dev/null; then
    sed -i 's/main/main contrib non-free non-free-firmware/g' /etc/apt/sources.list
fi

apt-get update
apt-get install -y zfsutils-linux zfs-dkms zfs-initramfs

# Compilar módulos
dkms autoinstall || true

# Atualizar initramfs
update-initramfs -u -k all

# Habilitar serviços
systemctl enable zfs-import-cache.service || true
systemctl enable zfs-mount.service || true
systemctl enable zfs.target || true

echo "ZFS configurado!"
ZFSHOOK

    # Hook KDE (para Workstation)
    cat > config/hooks/normal/0200-setup-kde.hook.chroot << 'KDEHOOK'
#!/bin/bash
set -e

# Verificar se KDE está instalado
if ! dpkg -l | grep -q plasma-desktop; then
    echo "KDE não instalado, pulando configuração..."
    exit 0
fi

echo "Configurando KDE Plasma..."

# Habilitar SDDM
systemctl enable sddm.service

# Configurar SDDM
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/kde_settings.conf << 'SDDMCONF'
[Theme]
Current=breeze

[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot
SDDMCONF

# Tema Breeze Dark padrão
mkdir -p /etc/skel/.config
cat > /etc/skel/.config/kdeglobals << 'KDEGLOBALS'
[General]
ColorScheme=BreezeDark
Name=Breeze Dark

[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
KDEGLOBALS

# Limpar GTK desnecessário
apt-get autoremove --purge -y gnome-keyring 2>/dev/null || true
apt-get clean

echo "KDE configurado!"
KDEHOOK

    # Hook de locale
    cat > config/hooks/normal/0050-setup-locale.hook.chroot << 'LOCALEHOOK'
#!/bin/bash
set -e
echo "Configurando locale pt_BR..."

echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
update-locale LANG=pt_BR.UTF-8

ln -sf /usr/share/zoneinfo/America/Cuiaba /etc/localtime

echo "Locale configurado!"
LOCALEHOOK

    chmod +x config/hooks/normal/*.hook.chroot
    
    log_ok "Hooks adicionados"
}

# =============================================================================
# BUILD
# =============================================================================

run_build() {
    log_info "Iniciando build da ISO..."
    log_info "Este processo pode demorar 30-60 minutos..."
    
    cd "${BUILD_DIR}"
    
    if lb build 2>&1 | tee /root/build.log; then
        log_ok "Build concluído!"
    else
        log_error "Build falhou. Verifique /root/build.log"
        exit 1
    fi
    
    # Mover ISO
    if ls *.iso 1>/dev/null 2>&1; then
        mv *.iso "${OUTPUT_DIR}/${ISO_NAME}"
        cd "${OUTPUT_DIR}"
        
        sha256sum "${ISO_NAME}" > "${ISO_NAME}.sha256"
        
        local size
        size=$(du -h "${ISO_NAME}" | cut -f1)
        
        log_ok "ISO gerada: ${OUTPUT_DIR}/${ISO_NAME}"
        log_info "Tamanho: ${size}"
        log_info "SHA256: $(cat ${ISO_NAME}.sha256)"
    else
        log_error "Nenhuma ISO gerada!"
        exit 1
    fi
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    echo "============================================="
    echo " Build de ISO Debian-ZFS"
    echo " Perfis: Server + Workstation"
    echo "============================================="
    
    setup_build_env
    configure_live_build
    
    # Adicionar todos os pacotes (Calamares selecionará perfil)
    add_base_packages
    add_server_packages
    add_workstation_packages
    add_calamares
    prepare_zfsbootmenu
    add_hooks
    
    run_build
    
    echo ""
    log_ok "Build completo!"
    log_info "ISO disponível em: ${OUTPUT_DIR}/${ISO_NAME}"
}

main "$@"
