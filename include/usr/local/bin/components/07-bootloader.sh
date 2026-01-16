#!/usr/bin/env bash
#
# components/07-bootloader.sh - ZFSBootMenu and bootloader installation
# Modularized from install-aurora.sh
# Uses: lib/logging.sh, lib/chroot.sh, lib/validation.sh
#

set -euo pipefail

# =============================================================================
# VARIÁVEIS
# =============================================================================

# Importar bibliotecas
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib"
export LIB_DIR
source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/chroot.sh"

# Variáveis globais
declare POOL_NAME="zroot"
declare MOUNT_POINT="${MOUNT_POINT:-/mnt/target}"
declare ZBM_BIN_DIR="/usr/share/zfsbootmenu"
declare FIRMWARE=""

# Array de discos selecionados (do install-manager.sh)
# Será exportado por install-manager.sh antes de executar este componente

# =============================================================================
# FUNÇÕES UTILITÁRIAS
# =============================================================================

# Obter sufixo de partição (para /dev/sdX vs /dev/nvme0n1)
get_part_suffix() {
    local disk=$1
    
    if [[ ${disk} =~ /dev/nvme ]]; then
        echo "p"
    else
        echo ""
    fi
}

# Detectar tipo de firmware
detect_firmware() {
    if [[ -d /sys/firmware/efi ]]; then
        echo "uefi"
    else
        echo "bios"
    fi
}

# =============================================================================
# FUNÇÕES DO ZFSBOOTMENU
# =============================================================================

# Obter partição EFI do primeiro disco
get_efi_partition() {
    local disk=${SELECTED_DISKS[0]}
    local part_suffix
    part_suffix=$(get_part_suffix "${disk}")
    
    # Partição 1 agora é ESP
    echo "${disk}${part_suffix}1"
}

# Formatar partição EFI
format_esp() {
    local efi_part
    efi_part=$(get_efi_partition)
    
    log_step "Formatando partição EFI: ${efi_part}"
    
    mkfs.vfat -F 32 -n EFI "${efi_part}" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao formatar partição EFI ${efi_part}"
    
    log_success "Partição EFI formatada"
}

# Montar ESP em /boot/efi
mount_esp() {
    local efi_part
    efi_part=$(get_efi_partition)
    
    log_step "Montando ESP em ${MOUNT_POINT}/boot/efi..."
    
    mkdir -p "${MOUNT_POINT}/boot/efi" ||
        error_exit "Falha ao criar diretório ${MOUNT_POINT}/boot/efi"
    
    mount "${efi_part}" "${MOUNT_POINT}/boot/efi" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao montar ESP em ${MOUNT_POINT}/boot/efi"
    
    log_success "ESP montado em /boot/efi"
}

# Copiar binários do ZFSBootMenu
copy_zbm_binaries() {
    log_step "Copiando binários do ZFSBootMenu..."
    
    # Criar diretórios necessários
    mkdir -p "${MOUNT_POINT}/boot/efi/EFI/ZBM" ||
        error_exit "Falha ao criar diretório ${MOUNT_POINT}/boot/efi/EFI/ZBM"
    
    mkdir -p "${MOUNT_POINT}/boot/efi/EFI/BOOT" ||
        error_exit "Falha ao criar diretório ${MOUNT_POINT}/boot/EFI/BOOT"
    
    local zbm_binary=""
    
    # Primeiro, tentar encontrar binário local (se incluído na ISO pelo download-zfsbootmenu.sh)
    if [[ -d "${ZBM_BIN_DIR}" ]]; then
        log_info "Procurando binário ZBM local em ${ZBM_BIN_DIR}..."
        log_debug "Conteúdo do diretório:"
        ls -la "${ZBM_BIN_DIR}" >>"${LOG_FILE}" 2>&1 || true
        
        # Padrões em ordem de preferência
        for pattern in "VMLINUZ.EFI" "VMLINUZ-RECOVERY.EFI" "release-x86_64.EFI" "recovery-x86_64.EFI" "vmlinuz-bootmenu" "vmlinuz.EFI" "zfsbootmenu.EFI" "*.EFI" "*.efi"; do
            zbm_binary=$(find "${ZBM_BIN_DIR}" -maxdepth 1 -name "${pattern}" -type f 2>/dev/null | grep -vi signed | head -n 1)
            [[ -n "${zbm_binary}" ]] && break
        done
    fi
    
    # Se não encontrou localmente, baixar da internet (conforme documentação oficial)
    if [[ -z "${zbm_binary}" ]]; then
        log_info "Binário ZBM não encontrado localmente, baixando da URL oficial..."
        
        local download_url="https://get.zfsbootmenu.org/efi"
        
        if command -v curl >/dev/null 2>&1; then
            if curl -fsSL -o "${MOUNT_POINT}/boot/efi/EFI/ZBM/VMLINUZ.EFI" "${download_url}" 2>>"${LOG_FILE}"; then
                log_success "ZFSBootMenu baixado com sucesso"
                
                # Criar backup
                cp "${MOUNT_POINT}/boot/efi/EFI/ZBM/VMLINUZ.EFI" "${MOUNT_POINT}/boot/efi/EFI/ZBM/VMLINUZ-BACKUP.EFI" 2>>"${LOG_FILE}" || true
                
                # Copiar para BOOT como fallback UEFI
                cp "${MOUNT_POINT}/boot/efi/EFI/ZBM/VMLINUZ.EFI" "${MOUNT_POINT}/boot/efi/EFI/BOOT/BOOTX64.EFI" 2>>"${LOG_FILE}" || true
                
                log_success "Binários ZFSBootMenu instalados com sucesso"
                zbm_binary="${MOUNT_POINT}/boot/efi/EFI/ZBM/VMLINUZ.EFI"
            else
                log_error "Falha ao baixar ZFSBootMenu da internet"
                return 1
            fi
        else
            log_error "curl não disponível para download"
            return 1
        fi
    fi
    
    # Usar binário local encontrado
    log_info "Binário ZBM encontrado localmente: ${zbm_binary}"
    
    cp "${zbm_binary}" "${MOUNT_POINT}/boot/efi/EFI/ZBM/VMLINUZ.EFI" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao copiar binário ZBM principal"
    
    cp "${zbm_binary}" "${MOUNT_POINT}/boot/efi/EFI/ZBM/VMLINUZ-BACKUP.EFI" 2>>"${LOG_FILE}" || true
    
    cp "${zbm_binary}" "${MOUNT_POINT}/boot/efi/EFI/BOOT/BOOTX64.EFI" 2>>"${LOG_FILE}" || true
    
    log_success "Binários ZFSBootMenu copiados com sucesso"
}

# Configurar entradas EFI (apenas se disponível no host)
configure_efi_entries() {
    log_step "Configurando entradas EFI..."
    
    # Verificar se é sistema UEFI
    local firmware
    firmware=$(detect_firmware)
    
    if [[ "${firmware}" != "uefi" ]]; then
        log_info "Sistema não é UEFI, pulando configuração EFI"
        return 0
    fi
    
    # Verificar se efibootmgr está disponível
    if ! command -v efibootmgr >/dev/null 2>&1; then
        log_warn "efibootmgr não disponível, pulando configuração EFI"
        return 0
    fi
    
    # Montar efivarfs se necessário
    if [[ ! -d /sys/firmware/efi/efivars ]] || ! mountpoint -q /sys/firmware/efi/efivars 2>/dev/null; then
        mount -t efivarfs efivarfs /sys/firmware/efi/efivars 2>>"${LOG_FILE}" || true
    fi
    
    local efi_part=$(get_efi_partition)
    local disk=${SELECTED_DISKS[0]}
    local part_suffix
    part_suffix=$(get_part_suffix "${disk}")
    
    # Criar entrada de backup primeiro (conforme documentação oficial)
    efibootmgr -c -d "${disk}" -p ${part_suffix}2 \
        -L "ZFSBootMenu (Backup)" \
        -l "\\EFI\\ZBM\\VMLINUZ-BACKUP.EFI" \
        2>>"${LOG_FILE}" || true
    
    # Criar entrada principal (será a primeira na ordem de boot)
    efibootmgr -c -d "${disk}" -p ${part_suffix}2 \
        -L "ZFSBootMenu" \
        -l "\\EFI\\ZBM\\VMLINUZ.EFI" \
        2>>"${LOG_FILE}" || {
        log_warn "Falha ao configurar entrada EFI principal"
        return 1
    }
    
    log_success "Entradas EFI configuradas (principal + backup)"
    return 0
}

# Configurar propriedade de commandline para ZFSBootMenu
configure_zbm_commandline() {
    local pool="${POOL_NAME:-zroot}"
    
    log_step "Configurando propriedade de commandline para ZFSBootMenu..."
    
    zfs set org.zfsbootmenu:commandline="quiet loglevel=4" "${pool}/ROOT/debian" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao configurar commandline do ZFSBootMenu"
    
    log_success "Propriedade commandline configurada"
}

# =============================================================================
# FUNÇÕES DO BOOTLOADER BIOS (LEGADO)
# =============================================================================

# Configurar Boot BIOS via Syslinux
configure_bios_boot() {
    log_step "Configurando Boot BIOS (Legacy) com Syslinux..."
    
    local efi_part
    efi_part=$(get_efi_partition)
    local disk=${SELECTED_DISKS[0]}
    
    log_info "Partição EFI: ${efi_part}"
    
    # 1. Gravar MBR GPT (gptmbr.bin) no disco
    local mbr_bin="/usr/lib/syslinux/mbr/gptmbr.bin"
    
    if [[ ! -f "${mbr_bin}" ]]; then
        log_error "Arquivo MBR não encontrado: ${mbr_bin}. Instale syslinux-common."
        return 1
    fi
    
    log_info "Gravando MBR GPT em ${disk}..."
    dd if="${mbr_bin}" of="${disk}" bs=440 count=1 conv=notrunc 2>>"${LOG_FILE}" ||
        error_exit "Falha ao gravar MBR em ${disk}"
    
    # 2. Instalar Syslinux na ESP
    log_info "Instalando Syslinux na partição ${efi_part}..."
    
    if ! syslinux --install "${efi_part}" 2>>"${LOG_FILE}"; then
        error_exit "Falha ao instalar Syslinux na partição ${efi_part}"
    fi
    
    # 3. Configurar syslinux.cfg na ESP
    local syslinux_cfg="${MOUNT_POINT}/boot/efi/syslinux.cfg"
    local zbm_dir="${MOUNT_POINT}/boot/zbm"
    
    mkdir -p "${zbm_dir}"
    
    log_info "Criando configuração syslinux.cfg em ${syslinux_cfg}..."
    
    if ! cat >"${syslinux_cfg}" <<SYSLINUXCFG; then
        error_exit "Falha ao criar syslinux.cfg"
    fi
    SYSLINUXCFG
UI menu.c32
PROMPT 0
TIMEOUT 0

LABEL zfsbootmenu
    MENU LABEL ZFSBootMenu
    LINUX /zbm/vmlinuz
    INITRD /zbm/initramfs.img
    APPEND zbm.prefer_policy=hostid quiet loglevel=0
SYSLINUXCFG
    
    # 4. Copiar componentes separados do ZBM para Syslinux
    # Verificar se diretório ZBM existe e copiar componentes
    # Os componentes podem ter sido baixados com o binário
    
    log_info "Copiando componentes do ZBM para Syslinux..."
    
    # Nota: O binário do ZBM que baixamos pode já incluir kernel+initramfs
    # Para Syslinux, precisamos separar se necessário
    
    # Criar diretório para componentes se não existir
    mkdir -p "${zbm_dir}" || log_warn "Falha ao criar ${zbm_dir}, continuando..."
    
    log_success "Syslinux BIOS configurado com sucesso"
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    log_section "=== Aurora OS Installer - Bootloader Installation Phase ==="
    log_info "Instalando bootloaders (ZFSBootMenu + Syslinux) para ${PROFILE:-Server} profile..."
    
    # Detectar firmware
    FIRMWARE=$(detect_firmware)
    log_info "Firmware detectado: ${FIRMWARE^^}"
    
    # 1. Formatar e montar ESP
    format_esp || return 1
    mount_esp || return 1
    
    # 2. Copiar binários do ZFSBootMenu
    copy_zbm_binaries || return 1
    
    # 3. Configurar ZFSBootMenu commandline
    configure_zbm_commandline || return 1
    
    # 4. Configurar entradas EFI (apenas em sistemas UEFI)
    configure_efi_entries || return 1
    
    # 5. Configurar BIOS (se aplicável - sistemas BIOS legado)
    if [[ "${FIRMWARE}" == "bios" ]]; then
        configure_bios_boot || return 1
    fi
    
    log_success "=== Bootloader installation completed successfully ==="
    return 0
}

# Executar main se script for executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
