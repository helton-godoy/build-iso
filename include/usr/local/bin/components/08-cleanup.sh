#!/usr/bin/env bash
#
# components/08-cleanup.sh - Final cleanup and unmounting
# Modularized from install-aurora.sh
# Uses: lib/logging.sh, lib/chroot.sh
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

# =============================================================================
# FUNÇÕES DE LIMPEZA
# =============================================================================

# Desmontar filesystems em ordem inversa
unmount_filesystems() {
    local target=${1:-${MOUNT_POINT}}
    local mount_order=(run sys proc dev)  # Ordem inversa para desmontar em ordem correta
    
    log_step "Unmounting virtual filesystems..."
    
    for dir in "${mount_order[@]}"; do
        local mountpoint="${target}/${dir}"
        if mountpoint -q "${mountpoint}" 2>/dev/null; then
            log_debug "Unmounting ${mountpoint}"
            umount -l "${mountpoint}" 2>/dev/null || true
        fi
    done
    
    log_success "Virtual filesystems unmounted"
}

# Desmontar datasets ZFS em ordem inversa
unmount_datasets() {
    local target=${1:-${MOUNT_POINT}}
    local pool="${2:-${POOL_NAME}}"
    
    log_step "Unmounting ZFS datasets in reverse order..."
    
    # Lista de datasets em ordem inversa de desmontagem
    local datasets=(
        "${pool}/var/tmp"
        "${pool}/var/cache"
        "${pool}/var/log"
        "${pool}/home/root"
        "${pool}/home"
        "${pool}/var"
        "${pool}/ROOT/debian"
        "${pool}/ROOT"
    )
    
    for dataset in "${datasets[@]}"; do
        if zfs list -o mountpoint -H "${dataset}" 2>/dev/null | grep -q "^/"; then
            log_debug "Unmounting dataset ${dataset}"
            zfs umount -f "${dataset}" 2>>"${LOG_FILE}" || true
        fi
    done
    
    # Desmontar ROOT/debian por último
    if zfs list -o mountpoint -H "${pool}/ROOT/debian" 2>/dev/null | grep -q "^/"; then
        log_debug "Unmounting ${pool}/ROOT/debian (final)"
        zfs umount -f "${pool}/ROOT/debian" 2>>"${LOG_FILE}" || true
    fi
    
    log_success "All ZFS datasets unmounted"
}

# Exportar pool ZFS
export_pool() {
    local pool="${1:-${POOL_NAME}}"
    
    log_step "Exporting ZFS pool ${pool}..."
    
    if zpool list "${pool}" >/dev/null 2>&1; then
        log_info "Pool ${pool} exists, starting export procedure..."
        
        # Sincronizar
        sync
        
        # Desabilitar swap se estiver em ZFS
        swapoff -a 2>>"${LOG_FILE}" || true
        
        # Desmontagem recursiva do mountpoint
        if [[ -d "${MOUNT_POINT}" ]]; then
            log_debug "Unmounting recursively ${MOUNT_POINT}..."
            umount -Rl "${MOUNT_POINT}" 2>>"${LOG_FILE}" || true
            sleep 1
        fi
        
        # Desmontar todos os datasets do pool (lazy)
        for ds in $(zfs list -H -o name -r "${pool}" 2>/dev/null | tac); do
            log "Unmounting dataset: ${ds}"
            zfs unmount -f "${ds}" 2>>"${LOG_FILE}" || true
        done
        
        # Tentar exportar
        sync
        sleep 1
        log_info "Attempting to export pool ${pool}..."
        if ! zpool export -f "${pool}" 2>>"${LOG_FILE}"; then
            log_warn "First export attempt failed, waiting and trying again..."
            sleep 2
            sync
            zpool export -f "${pool}" 2>>"${LOG_FILE}" || true
        fi
        
        if zpool list "${pool}" >/dev/null 2>&1; then
            log_warn "Pool still exists after export. Attempting to destroy..."
            zpool destroy -f "${pool}" 2>>"${LOG_FILE}" || true
        fi
        
        if zpool list "${pool}" >/dev/null 2>&1; then
            log_error "Failed to remove pool ${pool} even after destroy attempt."
            return 1
        fi
        
        log_success "Pool ${pool} exported successfully"
    else
        log_debug "Pool ${pool} not running, skipping export"
    fi
    
    return 0
}

# Criar snapshot final do sistema instalado
create_final_snapshot() {
    local pool="${1:-${POOL_NAME}}"
    
    log_step "Creating final snapshot..."
    
    # Verificar se snapshot já existe
    if zfs list -t snapshot | grep -q "${pool}/ROOT/debian@install-final"; then
        log_warn "Final snapshot already exists, recreating..."
        zfs destroy -r "${pool}/ROOT/debian@install-final" 2>>"${LOG_FILE}" || true
    fi
    
    if ! zfs snapshot "${pool}/ROOT/debian@install-final" 2>>"${LOG_FILE}"; then
        log_error "Failed to create final snapshot"
        return 1
    fi
    
    log_success "Final snapshot created: ${pool}/ROOT/debian@install-final"
    return 0
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    log_section "=== Aurora OS Installer - Cleanup Phase ==="
    log_info "Performing final cleanup..."
    
    # 1. Desmontar filesystems virtuais
    unmount_filesystems "${MOUNT_POINT}"
    
    # 2. Desmontar datasets ZFS
    unmount_datasets "${POOL_NAME}" "${MOUNT_POINT}"
    
    # 3. Criar snapshot final
    create_final_snapshot
    
    # 4. Exportar pool
    export_pool "${POOL_NAME}"
    
    # 5. Limpeza final
    sync
    
    log_success "=== All cleanup completed successfully ==="
    log_info "Sistema pronto para reboot."
    log_info "Boot com ZFSBootMenu ou use chroot via live system."
    
    return 0
}

# Executar main se script for executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
