#!/usr/bin/env bash
#
# components/04-datasets.sh - ZFS datasets with profile-specific logic
# Modularized from install-aurora.sh
# Uses: lib/logging.sh
#

set -euo pipefail

# =============================================================================
# VARIÁVEIS
# =============================================================================

# Importar bibliotecas
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib"
export LIB_DIR
source "${LIB_DIR}/logging.sh"

# Variáveis globais
declare POOL_NAME="zroot"
declare ASHIFT=12
declare COMPRESSION="zstd"
declare CHECKSUM="on"
declare COPIES=1
declare PROFILE="${PROFILE:-Server}"

# =============================================================================
# FUNÇÕES DE DATASETS POR PERFIL
# =============================================================================

# Criar datasets otimizados para perfil SERVER
create_server_datasets() {
    local pool=$1
    
    log_init_component "Creating SERVER Datasets for ${pool}"
    
    # Dataset ROOT (padrão)
    log_info "Creating ROOT dataset..."
    zfs create -o canmount=off -o mountpoint=none "${pool}/ROOT" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset ROOT"
    
    # Dataset ROOT/debian (padrão)
    log_info "Creating ROOT/debian dataset..."
    zfs create -o canmount=noauto -o mountpoint=/ -o com.sun:auto-snapshot=true "${pool}/ROOT/debian" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset ROOT/debian"
    
    # Dataset home (sem auto-snapshot para servidor)
    log_info "Creating home dataset (no auto-snapshot)..."
    zfs create -o mountpoint=/home -o com.sun:auto-snapshot=false "${pool}/home" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset home"
    
    # Dataset home/root
    log_info "Creating home/root dataset..."
    zfs create -o mountpoint=/root "${pool}/home/root" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset home/root"
    
    # Dataset var/log (compressão zstd para logs de servidor)
    log_info "Creating var/log dataset (zstd compression)..."
    zfs create -o mountpoint=/var/log -o compression=zstd -o atime=off -o xattr=sa "${pool}/var/log" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset var/log"
    
    # Dataset var/cache (compressão lz4 para cache de servidor)
    log_info "Creating var/cache dataset (lz4 compression)..."
    zfs create -o mountpoint=/var/cache -o compression=lz4 -o atime=off -o xattr=sa "${pool}/var/cache" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset var/cache"
    
    # Dataset var/backups (para backups do servidor)
    log_info "Creating var/backups dataset..."
    zfs create -o mountpoint=/var/backups -o compression=zstd -o atime=off -o xattr=sa "${pool}/var/backups" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset var/backups"
    
    # Dataset srv (para dados do servidor)
    log_info "Creating srv dataset..."
    zfs create -o mountpoint=/srv -o compression=lz4 -o atime=off -o xattr=sa "${pool}/srv" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset srv"
    
    log_success "All SERVER datasets created successfully"
    return 0
}

# Criar datasets otimizados para perfil WORKSTATION
create_workstation_datasets() {
    local pool=$1
    
    log_init_component "Creating WORKSTATION Datasets for ${pool}"
    
    # Dataset ROOT (padrão)
    log_info "Creating ROOT dataset..."
    zfs create -o canmount=off -o mountpoint=none "${pool}/ROOT" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset ROOT"
    
    # Dataset ROOT/debian (padrão)
    log_info "Creating ROOT/debian dataset..."
    zfs create -o canmount=noauto -o mountpoint=/ -o com.sun:auto-snapshot=true "${pool}/ROOT/debian" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset ROOT/debian"
    
    # Dataset home (com auto-snapshot para desktop)
    log_info "Creating home dataset (with auto-snapshot)..."
    zfs create -o mountpoint=/home -o com.sun:auto-snapshot=true "${pool}/home" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset home"
    
    # Dataset home/user (para usuário do desktop)
    log_info "Creating home/user dataset..."
    zfs create -o mountpoint=/home/user -o com.sun:auto-snapshot=true "${pool}/home/user" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset home/user"
    
    # Dataset data (para dados pessoais do desktop)
    log_info "Creating data dataset with daily snapshots..."
    zfs create -o mountpoint=/data -o compression=zstd -o com.sun:auto-snapshot=daily "${pool}/data" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset data"
    
    # Dataset var/cache (compressão lz4 para cache do desktop)
    log_info "Creating var/cache dataset (lz4 compression)..."
    zfs create -o mountpoint=/var/cache -o compression=lz4 -o atime=off -o xattr=sa "${pool}/var/cache" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset var/cache"
    
    # Dataset var/log (compressão lz4 para logs do desktop)
    log_info "Creating var/log dataset (lz4 compression)..."
    zfs create -o mountpoint=/var/log -o compression=lz4 -o atime=off -o xattr=sa "${pool}/var/log" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset var/log"
    
    # Dataset var/tmp (sem snapshot)
    log_info "Creating var/tmp dataset (no snapshot)..."
    zfs create -o com.sun:auto-snapshot=false "${pool}/var/tmp" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset var/tmp"
    
    log_success "All WORKSTATION datasets created successfully"
    return 0
}

# Criar datasets para perfil padrão (fallback)
create_default_datasets() {
    local pool=$1
    
    log_init_component "Creating Default Datasets for ${pool}"
    
    # Datasets básicos
    zfs create -o canmount=off -o mountpoint=none "${pool}/ROOT" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset ROOT"
    
    zfs create -o canmount=noauto -o mountpoint=/ -o com.sun:auto-snapshot=true "${pool}/ROOT/debian" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset ROOT/debian"
    
    zfs create -o mountpoint=/home -o com.sun:auto-snapshot=true "${pool}/home" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset home"
    
    zfs create -o mountpoint=/root "${pool}/home/root" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset home/root"
    
    zfs create -o mountpoint=/var -o canmount=off "${pool}/var" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset var"
    
    zfs create -o com.sun:auto-snapshot=true "${pool}/var/log" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset var/log"
    
    zfs create -o com.sun:auto-snapshot=false "${pool}/var/cache" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset var/cache"
    
    zfs create -o com.sun:auto-snapshot=false "${pool}/var/tmp" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset var/tmp"
    
    log_success "Default datasets created successfully"
    return 0
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    log_section "=== Aurora OS Installer - Datasets Phase ==="
    log_info "Creating ZFS datasets for ${PROFILE^^} profile..."
    
    local pool="${POOL_NAME}"
    
    # Criar datasets base no ROOT e var primeiro
    log_step "Creating ROOT and var base datasets"
    zfs create -o canmount=off -o mountpoint=none "${pool}/ROOT" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset ROOT"
    
    zfs create -o canmount=noauto -o mountpoint=/ -o com.sun:auto-snapshot=true "${pool}/ROOT/debian" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset ROOT/debian"
    
    zfs create -o mountpoint=/var -o canmount=off "${pool}/var" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao criar dataset var"
    
    # Criar datasets específicos por perfil
    case "$PROFILE" in
        Server)
            create_server_datasets "${pool}"
            ;;
        Workstation)
            create_workstation_datasets "${pool}"
            ;;
        *)
            log_warn "Profile ${PROFILE} not recognized, using default datasets"
            create_default_datasets "${pool}"
            ;;
    esac
    
    # Configurar propriedade de commandline para ZFSBootMenu
    log_step "Configuring ZFSBootMenu commandline..."
    zfs set org.zfsbootmenu:commandline="quiet" "${pool}/ROOT/debian" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao configurar commandline do ZFSBootMenu"
    
    # Definir bootfs padrão
    log_step "Setting bootfs default..."
    zpool set bootfs="${pool}/ROOT/debian" "${pool}" 2>>"${LOG_FILE}" ||
        error_exit "Falha ao definir bootfs"
    
    log_success "=== All datasets created and configured successfully ==="
    return 0
}

# Executar main se script for executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
