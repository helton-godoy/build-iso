#!/bin/bash
# =============================================================================
# create_vm.sh - Cria VM Debian 13 headless usando ISO netinst + preseed
# Instalação automatizada e confiável
# =============================================================================

set -euo pipefail

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

VM_NAME="debian-iso-builder"
VM_MEMORY="4096"
VM_VCPUS="4"
VM_DISK_SIZE="40"

# Diretórios
IMAGES_DIR="${PROJECT_ROOT}/images"
VM_DISK_PATH="${IMAGES_DIR}/${VM_NAME}.qcow2"
PRESEED_DIR="${IMAGES_DIR}/preseed"

# URL da ISO netinst Debian 13 (Trixie)
DEBIAN_ISO_URL="https://debian.c3sl.ufpr.br/debian-cd/13.2.0/amd64/iso-cd/debian-13.2.0-amd64-netinst.iso"
DEBIAN_ISO="${IMAGES_DIR}/debian-13-netinst.iso"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $*" >&2; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*" >&2; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERRO]${NC} $*" >&2; }

# =============================================================================
# FUNÇÕES
# =============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Execute como root: sudo $0"
        exit 1
    fi
}

cleanup_existing_vm() {
    log_info "Verificando VM existente..."
    
    if virsh list --all 2>/dev/null | grep -q "${VM_NAME}"; then
        local vm_state
        vm_state=$(virsh domstate "${VM_NAME}" 2>/dev/null || echo "desconhecido")
        
        echo ""
        log_warn "VM '${VM_NAME}' já existe (Estado: ${vm_state})"
        echo ""
        echo "O que deseja fazer?"
        echo "  1) Parar e excluir a VM (recriar do zero)"
        echo "  2) Cancelar (manter a VM como está)"
        echo ""
        read -p "Escolha [1/2]: " choice
        
        case "$choice" in
            1)
                log_info "Parando e removendo VM..."
                virsh destroy "${VM_NAME}" 2>/dev/null || true
                virsh undefine "${VM_NAME}" --remove-all-storage 2>/dev/null || true
                rm -rf "${PRESEED_DIR}" 2>/dev/null || true
                rm -f "${VM_DISK_PATH}" 2>/dev/null || true
                log_ok "VM removida com sucesso"
                ;;
            2|*)
                log_info "Operação cancelada pelo usuário."
                exit 0
                ;;
        esac
    fi
    
    # Limpar arquivos residuais
    rm -f "${VM_DISK_PATH}" 2>/dev/null || true
    rm -rf "${PRESEED_DIR}" 2>/dev/null || true
    
    log_ok "Limpeza concluída"
}

download_iso() {
    log_info "Verificando ISO do Debian..."
    
    mkdir -p "${IMAGES_DIR}"
    
    if [[ -f "${DEBIAN_ISO}" ]]; then
        log_ok "ISO já existe: ${DEBIAN_ISO}"
        return 0
    fi
    
    log_info "Baixando ISO netinst do Debian 13..."
    log_info "URL: ${DEBIAN_ISO_URL}"
    
    wget -q --show-progress -O "${DEBIAN_ISO}" "${DEBIAN_ISO_URL}"
    
    log_ok "ISO baixada: ${DEBIAN_ISO}"
}

generate_ssh_key() {
    local ssh_dir="${PROJECT_ROOT}/.ssh"
    local key_path="${ssh_dir}/vm_key"
    
    mkdir -p "${ssh_dir}"
    
    if [[ ! -f "${key_path}" ]]; then
        echo -e "${BLUE}[INFO]${NC} Gerando chave SSH..." >&2
        ssh-keygen -t ed25519 -f "${key_path}" -N "" -C "build-vm" >/dev/null
        chmod 600 "${key_path}"
        chmod 644 "${key_path}.pub"
    fi
    
    echo -e "${GREEN}[OK]${NC} Chave SSH: ${key_path}" >&2
    echo "${key_path}"
}

create_preseed_config() {
    log_info "Criando configuração preseed..."
    
    local internal_ssh_key_path="$1"
    local internal_pub_key
    internal_pub_key=$(cat "${internal_ssh_key_path}.pub")
    
    # Coletar todas as chaves públicas do usuário no host para garantir acesso sem senha
    local user_pub_keys=""
    if ls "${HOME}/.ssh"/*.pub &>/dev/null; then
        log_info "Detectadas chaves SSH do usuário em ~/.ssh/, incluindo na VM..."
        user_pub_keys=$(cat "${HOME}/.ssh"/*.pub)
    fi
    
    # Unir chaves (interna + usuário)
    local all_authorized_keys="${internal_pub_key}"
    if [[ -n "${user_pub_keys}" ]]; then
        all_authorized_keys="${all_authorized_keys}\n${user_pub_keys}"
    fi
    
    mkdir -p "${PRESEED_DIR}"
    
    cat > "${PRESEED_DIR}/preseed.cfg" << EOF
# =============================================================================
# Preseed para Debian 13 - VM de Build ISO
# Instalação completamente automatizada
# =============================================================================

# Localização - Português Brasil COMPLETO
d-i debian-installer/language string pt
d-i debian-installer/country string BR
d-i debian-installer/locale string pt_BR.UTF-8
d-i localechooser/supported-locales multiselect pt_BR.UTF-8, en_US.UTF-8

# Teclado
d-i keyboard-configuration/xkb-keymap select br
d-i keyboard-configuration/layoutcode string br

# Fuso horário
d-i time/zone string America/Cuiaba
d-i clock-setup/utc boolean true
d-i clock-setup/ntp boolean true

# Rede (DHCP automático)
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string ${VM_NAME}
d-i netcfg/get_domain string local

# Mirror
d-i mirror/country string BR
d-i mirror/http/hostname string deb.debian.org
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string

# Conta root
d-i passwd/root-login boolean true
d-i passwd/root-password password root
d-i passwd/root-password-again password root
d-i passwd/make-user boolean false

# Particionamento (automático, usar disco inteiro)
d-i partman-auto/disk string /dev/vda
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

# Base system
d-i base-installer/kernel/image string linux-image-amd64

# Apt
d-i apt-setup/non-free-firmware boolean true
d-i apt-setup/non-free boolean true
d-i apt-setup/contrib boolean true
d-i apt-setup/services-select multiselect security, updates
d-i apt-setup/security_host string security.debian.org

# Seleção de pacotes (mínimo + SSH + ZFS para compilação)
tasksel tasksel/first multiselect standard, ssh-server
d-i pkgsel/include string openssh-server sudo curl wget git vim htop live-build debootstrap squashfs-tools xorriso isolinux syslinux-efi mtools dosfstools rsync jq zfsutils-linux zfs-dkms linux-headers-amd64 dkms

# Aceitar licença ZFS automaticamente
zfs-dkms zfs-dkms/note-incompatible-licenses note

# Pular pergunta sobre atualizações automáticas
d-i pkgsel/update-policy select none
d-i pkgsel/upgrade select full-upgrade

# GRUB - Configuração simplificada e robusta
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean false
d-i grub-installer/bootdev string /dev/vda

# Finalização
d-i finish-install/reboot_in_progress note

# Comandos pós-instalação
d-i preseed/late_command string \
    mkdir -p /target/root/.ssh; \
    printf "${all_authorized_keys}\n" > /target/root/.ssh/authorized_keys; \
    chmod 700 /target/root/.ssh; \
    chmod 600 /target/root/.ssh/authorized_keys; \
    sed -i 's/.*PermitRootLogin.*/PermitRootLogin yes/' /target/etc/ssh/sshd_config; \
    mkdir -p /target/root/build-iso; \
    echo 'build-iso /root/build-iso virtiofs rw,relatime,nofail 0 0' >> /target/etc/fstab; \
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="console=tty0 console=ttyS0,115200n8 /' /target/etc/default/grub; \
    in-target update-grub; \
    echo "VM configurada com sucesso!" > /target/root/vm_ready.txt
EOF

    log_ok "Preseed criado: ${PRESEED_DIR}/preseed.cfg"
}

create_vm_disk() {
    log_info "Criando disco da VM..."
    
    qemu-img create -f qcow2 "${VM_DISK_PATH}" "${VM_DISK_SIZE}G"
    
    log_ok "Disco criado: ${VM_DISK_PATH} (${VM_DISK_SIZE}G)"
}

start_installation() {
    log_info "Iniciando instalação automatizada..."
    log_info "Este processo leva ~15-20 minutos..."
    
    local shared_dir="${PROJECT_ROOT}"
    # O diretório compartilhado agora é a raiz do projeto para permitir acesso direto aos scripts
    chmod 777 "${shared_dir}"
    
    # Iniciar VM com instalação preseed + virtiofs (modo BIOS)
    virt-install \
        --name "${VM_NAME}" \
        --memory "${VM_MEMORY}" \
        --vcpus "${VM_VCPUS}" \
        --disk "path=${VM_DISK_PATH},format=qcow2,bus=virtio" \
        --location "${DEBIAN_ISO}" \
        --os-variant debian12 \
        --network network=default,model=virtio \
        --graphics none \
        --console pty,target_type=serial \
        --filesystem "source=${shared_dir},target=build-iso,driver.type=virtiofs" \
        --memorybacking source.type=memfd,access.mode=shared \
        --extra-args "auto=true priority=critical preseed/file=/preseed.cfg debian-installer/locale=pt_BR.UTF-8 debian-installer/language=pt debian-installer/country=BR keyboard-configuration/xkb-keymap=br console=tty0 console=ttyS0,115200n8" \
        --initrd-inject="${PRESEED_DIR}/preseed.cfg" \
        --noautoconsole \
        --wait -1
    
    log_ok "Instalação concluída!"
}

wait_for_vm() {
    log_info "Aguardando VM reiniciar..."

    sleep 30s
    
    local ssh_key="${PROJECT_ROOT}/.ssh/vm_key"
    local max_attempts=60
    local attempt=1
    local vm_ip=""


    sleep 30s

    while [[ $attempt -le $max_attempts ]]; do
        vm_ip=$(virsh domifaddr "${VM_NAME}" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u || echo "")
        
        if [[ -n "${vm_ip}" ]]; then
            if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes \
                   -i "${ssh_key}" root@"${vm_ip}" "test -f /root/vm_ready.txt" &>/dev/null; then
                echo ""
                log_ok "VM pronta! IP: ${vm_ip}"
                echo "${vm_ip}"
                return 0
            fi
        fi
        
        echo -n "."
        sleep 10
        ((attempt++))
    done
    
    echo ""
    log_error "Timeout aguardando VM"
    return 1
}

save_vm_info() {
    local vm_ip="$1"
    
    cat > "${PROJECT_ROOT}/.vm_info" << EOF
VM_NAME=${VM_NAME}
VM_IP=${vm_ip}
SSH_KEY=${PROJECT_ROOT}/.ssh/vm_key
EOF
    
    log_ok "Informações salvas em .vm_info"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    echo "============================================="
    echo " Criando VM Debian 13 (Preseed Automatizado)"
    echo "============================================="
    
    check_root
    cleanup_existing_vm
    download_iso
    
    local ssh_key_path
    ssh_key_path=$(generate_ssh_key)
    
    create_preseed_config "${ssh_key_path}"
    create_vm_disk
    start_installation
    
    local vm_ip
    vm_ip=$(wait_for_vm)
    
    save_vm_info "${vm_ip}"
    
    echo ""
    log_ok "VM criada com sucesso!"
    echo ""
    log_info "Para acessar: ssh -i ${PROJECT_ROOT}/.ssh/vm_key root@${vm_ip}"
    log_info "Senha root: root"
}

main "$@"
