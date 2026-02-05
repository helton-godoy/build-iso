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
# TESTE UNITÁRIO (quando executado diretamente)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	echo "=== Teste de Configuração ZFS ==="
	echo
	echo "Funções disponíveis:"
	echo "  zfs_create_pool <device> [pool_name]"
	echo "  zfs_create_datasets [pool_name]"
	echo "  zfs_export_pool [pool_name]"
	echo "  zfs_pool_exists [pool_name]"
fi
