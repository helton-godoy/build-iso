#!/usr/bin/env bash
#
# zfs-setup.sh - Criação de pool ZFS e datasets para ZFSBootMenu
#

set -euo pipefail

# Nome padrão do pool
POOL_NAME="zroot"
MOUNT_POINT="/mnt"

# ============================================================================
# FUNÇÕES PÚBLICAS
# ============================================================================

# Cria o pool ZFS com propriedades otimizadas
# Uso: zfs_create_pool <device> [pool_name]
zfs_create_pool() {
	local device="$1"
	local pool="${2:-$POOL_NAME}"

	if [[ ! -b "$device" ]]; then
		return 1
	fi

	# Destrói pool existente se houver
	if zpool list "$pool" &>/dev/null; then
		zpool destroy -f "$pool" || true
	fi

	# Cria pool com propriedades otimizadas
	zpool create -f \
		-o ashift=12 \
		-o autotrim=on \
		-O acltype=posixacl \
		-O canmount=off \
		-O compression=zstd \
		-O dnodesize=auto \
		-O normalization=formD \
		-O relatime=on \
		-O xattr=sa \
		-O mountpoint=none \
		"$pool" "$device"
}

# Cria a hierarquia de datasets ZBM
# Uso: zfs_create_datasets [pool_name]
zfs_create_datasets() {
	local pool="${1:-$POOL_NAME}"

	# Verifica se pool existe
	if ! zpool list "$pool" &>/dev/null; then
		return 1
	fi

	# Cria estrutura base
	# zroot/ROOT - container de boot environments
	zfs create -o canmount=off -o mountpoint=none "$pool/ROOT"

	# Define commandline para ZFSBootMenu no container ROOT
	zfs set org.zfsbootmenu:commandline="quiet" "$pool/ROOT"

	# Boot Environment inicial
	zfs create -o canmount=noauto -o mountpoint=/ "$pool/ROOT/debian"

	# Dados de usuários
	zfs create -o mountpoint=/home "$pool/home"

	# /var separado
	zfs create -o canmount=off -o mountpoint=/var "$pool/var"
	zfs create "$pool/var/log"
	zfs create -o com.sun:auto-snapshot=false "$pool/var/tmp"

	# Cria diretório de mount e monta o BE
	mkdir -p "$MOUNT_POINT"
	zfs mount "$pool/ROOT/debian"
}

# Exporta o pool
# Uso: zfs_export_pool [pool_name]
zfs_export_pool() {
	local pool="${1:-$POOL_NAME}"

	# Desmonta tudo
	umount -R "$MOUNT_POINT" 2>/dev/null || true

	# Exporta pool
	zpool export "$pool"
}

# Importa o pool
# Uso: zfs_import_pool [pool_name]
zfs_import_pool() {
	local pool="${1:-$POOL_NAME}"

	zpool import -N "$pool"
}

# Retorna o nome do pool
zfs_get_pool_name() {
	echo "$POOL_NAME"
}

# Retorna o mount point
zfs_get_mount_point() {
	echo "$MOUNT_POINT"
}

# Verifica se pool existe
zfs_pool_exists() {
	local pool="${1:-$POOL_NAME}"
	zpool list "$pool" &>/dev/null
}

# Lista datasets do pool
zfs_list_datasets() {
	local pool="${1:-$POOL_NAME}"
	zfs list -r "$pool"
}

# Define propriedade de boot
zfs_set_bootfs() {
	local dataset="$1"
	zpool set bootfs="$dataset" "$POOL_NAME"
}

# ============================================================================
# ZFSUTILS ADAPTERS (API Compatibility)
# ============================================================================

zfsutils_pool_exists() {
    zfs_pool_exists "$1"
}

zfsutils_umount_all_under_altroot() {
    local pool="$1"
    # Tenta desmontar tudo montado sob /mnt (assumindo altroot ou mountpoints manuais)
    zfs unmount -u "${pool}" 2>/dev/null || true
    umount -R "$MOUNT_POINT" 2>/dev/null || true
}

zfsutils_export_pool() {
    zpool export "$1"
}

zfsutils_pool_create_single() {
    local pool="$1"
    local disk="$2"
    local ashift="${3:-12}"
    local comp="${4:-zstd}"
    local dedup="${5:-off}"
    local mountpoint="${6:-/mnt}"
    
    if zpool list "$pool" &>/dev/null; then
        zpool destroy -f "$pool" || true
    fi
    
    # Cria pool com propriedades
    zpool create -f \
        -o ashift="$ashift" \
        -o autotrim=on \
        -O acltype=posixacl \
        -O canmount=off \
        -O compression="$comp" \
        -O dedup="$dedup" \
        -O dnodesize=auto \
        -O normalization=formD \
        -O relatime=on \
        -O xattr=sa \
        -O mountpoint=none \
        "$pool" "$disk"
}

zfsutils_create_root_datasets() {
    local pool="$1"
    local root_ds="$2"
    local target="$3"
    
    # Garante estrutura base
    zfs create -o canmount=off -o mountpoint=none "${pool}/ROOT" 2>/dev/null || true
    zfs set org.zfsbootmenu:commandline="quiet" "${pool}/ROOT"
    
    # Cria root dataset do SO
    zfs create -o canmount=noauto -o mountpoint=/ "$root_ds"
    
    # Monta temporariamente no target
    zfs set mountpoint="$target" "$root_ds"
    zfs mount "$root_ds" 2>/dev/null || true
    
    # Datasets adicionais padrão
    zfs create -o mountpoint=/home "$pool/home"
    zfs create -o canmount=off -o mountpoint=/var "$pool/var"
    zfs create "$pool/var/log"
    zfs create -o com.sun:auto-snapshot=false "$pool/var/tmp"
}

zfsutils_create_dataset_preset_default() {
    : # Já criado acima ou implementações futuras
}

zfsutils_create_dataset_preset_server() {
    : # Stub
}

zfsutils_set_mountpoints_final() {
    local root_ds="$1"
    zfs set mountpoint=/ "$root_ds"
}

zfsutils_apply_arc_tuning_target_file() {
    local target="$1"
    local mode="$2"
    local max="$3"
    
    if [[ -n "$max" ]]; then
        mkdir -p "$target/etc/modprobe.d"
        echo "options zfs zfs_arc_max=$max" > "$target/etc/modprobe.d/zfs.conf"
    fi
}

