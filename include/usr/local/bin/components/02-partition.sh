#!/usr/bin/env bash
#
# components/02-partition.sh - Partitioning with profile-specific logic
# Modularized from install-aurora.sh
# Uses: lib/logging.sh, lib/validation.sh
#

set -euo pipefail

# =============================================================================
# VARIÁVEIS
# =============================================================================

# Importar bibliotecas
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib"
export LIB_DIR
source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/validation.sh"

# Variáveis globais (podem ser sobreescritas pelo orquestrador)
declare -a SELECTED_DISKS=()
declare RAID_TOPOLOGY=""
declare ASHIFT=12
declare COMPRESSION="zstd"
declare CHECKSUM="on"
declare COPIES=1
declare HDSIZE=""
declare ENCRYPTION="off"
declare ENCRYPTION_PASSPHRASE=""
declare PROFILE="${PROFILE:-Server}"  # Padrão: Server

# =============================================================================
# FUNÇÕES UTILITÁRIAS
# =============================================================================

# Determinar sufixo de partição (para /dev/sdX vs /dev/nvme0n1)
get_part_suffix() {
    local disk=$1
    
    if [[ ${disk} =~ /dev/nvme ]]; then
        echo "p"
    else
        echo ""
    fi
}

# Limpar completamente um disco
wipe_disk() {
    local disk=$1
    
    log_info "Wiping disk ${disk}..."
    
    if ! wipefs -a "${disk}" 2>>"${LOG_FILE}"; then
        error_exit "Falha ao executar wipefs em ${disk}"
    fi
    
    if ! sgdisk --zap-all "${disk}" 2>>"${LOG_FILE}"; then
        error_exit "Falha ao executar sgdisk --zap-all em ${disk}"
    fi
    
    sync
    log_success "Disk ${disk} wiped successfully"
}

# Particionar disco WORKSTATION
# ESP: 512MB (maior para acomodar GUI e drivers)
partition_workstation_disk() {
    local disk=$1
    local part_suffix
    part_suffix=$(get_part_suffix "${disk}")
    
    log_info "Partitioning WORKSTATION disk: ${disk}"
    log_debug "  ESP size: 512MB (larger for GUI/drivers)"
    log_debug "  ZFS: Remaining space"
    
    # ESP maior para Workstation (512MB)
    sgdisk -n 1:2048:+512M -t 1:EF00 -c 1:'EFI System' "${disk}" 2>>"${LOG_FILE}" || error_exit "Falha ao criar partição EFI em ${disk}"
    sgdisk -A 1:set:2 "${disk}" 2>>"${LOG_FILE}" || error_exit "Falha ao definir atributo Legacy Boot na ESP"
    
    # ZFS principal (restante)
    sgdisk -n 2:0:0 -t 2:BF00 -c 2:'ZFS Root' "${disk}" 2>>"${LOG_FILE}" || error_exit "Falha ao criar partição ZFS em ${disk}"
    
    partprobe "${disk}" 2>>"${LOG_FILE}" || error_exit "Falha ao executar partprobe em ${disk}"
    sync
    log_success "WORKSTATION disk ${disk} partitioned successfully"
}

# Particionar disco SERVER
# ESP: 256MB (menor - servidor sem GUI)
partition_server_disk() {
    local disk=$1
    local part_suffix
    part_suffix=$(get_part_suffix "${disk}")
    
    log_info "Partitioning SERVER disk: ${disk}"
    log_debug "  ESP size: 256MB (smaller - no GUI)"
    log_debug "  ZFS: Remaining space"
    
    # ESP menor para Server (256MB)
    sgdisk -n 1:2048:+256M -t 1:EF00 -c 1:'EFI System' "${disk}" 2>>"${LOG_FILE}" || error_exit "Falha ao criar partição EFI em ${disk}"
    sgdisk -A 1:set:2 "${disk}" 2>>"${LOG_FILE}" || error_exit "Falha ao definir atributo Legacy Boot na ESP"
    
    # ZFS principal (restante)
    sgdisk -n 2:0:0 -t 2:BF00 -c 2:'ZFS Root' "${disk}" 2>>"${LOG_FILE}" || error_exit "Falha ao criar partição ZFS em ${disk}"
    
    partprobe "${disk}" 2>>"${LOG_FILE}" || error_exit "Falha ao executar partprobe em ${disk}"
    sync
    log_success "SERVER disk ${disk} partitioned successfully"
}

# Particionar disco por perfil
partition_disk() {
    local disk=$1
    
    case "$PROFILE" in
        Server)
            partition_server_disk "${disk}"
            ;;
        Workstation)
            partition_workstation_disk "${disk}"
            ;;
        *)
            log_warn "Profile ${PROFILE} not recognized, using SERVER defaults"
            partition_server_disk "${disk}"
            ;;
    esac
}

# Preparar todos os discos selecionados
prepare_disks() {
    log_init_component "Preparing Disks for ${PROFILE^^} Profile"
    
    for disk in "${SELECTED_DISKS[@]}"; do
        local disk_title
        if [[ -n "${HDSIZE}" ]]; then
            disk_title="${disk} (${HDSIZE}GB)"
        else
            disk_title="${disk}"
        fi
        
        partition_disk "${disk}"
    done
    
    # Atualizar symlinks de dispositivos após particionamento
    udevadm trigger 2>>"${LOG_FILE}" || log_warn "Falha ao executar udevadm trigger"
    udevadm settle 2>>"${LOG_FILE}" || log_warn "Falha ao executar udevadm settle"
    
    log_end_component "Preparing Disks"
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    # Validar discos selecionados
    if [[ ${#SELECTED_DISKS[@]} -eq 0 ]]; then
        error_exit "Nenhum disco selecionado"
    fi
    
    for disk in "${SELECTED_DISKS[@]}"; do
        if [[ ! -b "${disk}" ]]; then
            error_exit "Dispositivo inválido: ${disk}"
        fi
    done
    
    log_step "Partitioning disks for ${PROFILE^^} profile"
    prepare_disks
}

# Executar main se script for executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
