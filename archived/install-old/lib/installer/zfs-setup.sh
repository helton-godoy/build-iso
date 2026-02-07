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

# Tipos de pool suportados
POOL_TYPES=("stripe" "mirror" "raidz1" "raidz2" "raidz3")

# Calcula espaço utilizável baseado no tipo de pool
# Uso: zfs_calculate_usable_space <tipo> <num_discos> <tamanho_disco_gb>
zfs_calculate_usable_space() {
	local pool_type="$1"
	local num_disks="$2"
	local disk_size_gb="${3:-10}"

	local usable_gb=0
	case "$pool_type" in
	stripe)
		usable_gb=$((num_disks * disk_size_gb))
		;;
	mirror)
		usable_gb=$disk_size_gb
		;;
	raidz1)
		usable_gb=$(((num_disks - 1) * disk_size_gb))
		;;
	raidz2)
		usable_gb=$(((num_disks - 2) * disk_size_gb))
		;;
	raidz3)
		usable_gb=$(((num_disks - 3) * disk_size_gb))
		;;
	esac
	echo "$usable_gb"
}

# Valida se o tipo de pool é válido para o número de discos
# Uso: zfs_validate_pool_type <tipo> <num_discos>
zfs_validate_pool_type() {
	local pool_type="$1"
	local num_disks="$2"

	case "$pool_type" in
	stripe)
		[[ $num_disks -ge 1 ]]
		;;
	mirror)
		[[ $num_disks -ge 2 ]]
		;;
	raidz1)
		[[ $num_disks -ge 3 ]]
		;;
	raidz2)
		[[ $num_disks -ge 4 ]]
		;;
	raidz3)
		[[ $num_disks -ge 5 ]]
		;;
	*)
		return 1
		;;
	esac
}

# Retorna tipos de pool disponíveis para N discos
# Uso: zfs_get_available_pool_types <num_discos>
zfs_get_available_pool_types() {
	local num_disks="$1"
	local available=()

	for ptype in "${POOL_TYPES[@]}"; do
		if zfs_validate_pool_type "$ptype" "$num_disks"; then
			available+=("$ptype")
		fi
	done

	printf '%s\n' "${available[@]}"
}

# Cria o pool ZFS com propriedades otimizadas
# Uso: zfs_create_pool <pool_type> <device1> [device2] [device3] ... [pool_name]
# Exemplos:
#   zfs_create_pool stripe /dev/vda3
#   zfs_create_pool mirror /dev/vda3 /dev/vdb1
#   zfs_create_pool raidz1 /dev/vda3 /dev/vdb1 /dev/vdc1
zfs_create_pool() {
	local pool_type="$1"
	shift

	# Coleta dispositivos (tudo menos o último argumento se for pool name)
	local devices=()
	local pool="$POOL_NAME"

	while [[ $# -gt 0 ]]; do
		if [[ -b "$1" ]]; then
			devices+=("$1")
		elif [[ $# -eq 1 && ! -b "$1" ]]; then
			# Último argumento não é dispositivo, é o nome do pool
			pool="$1"
		fi
		shift
	done

	local num_devices=${#devices[@]}

	if [[ $num_devices -eq 0 ]]; then
		echo "ERRO: Nenhum dispositivo especificado" >&2
		return 1
	fi

	# Valida tipo de pool
	if ! zfs_validate_pool_type "$pool_type" "$num_devices"; then
		echo "ERRO: Tipo '$pool_type' requer mais discos (tem: $num_devices)" >&2
		return 1
	fi

	# Destrói pool existente se houver
	if zpool list "$pool" &>/dev/null; then
		zpool destroy -f "$pool" || true
	fi

	# Gera hostid se não existir
	if [[ ! -f /etc/hostid ]]; then
		zgenhostid -f 2>/dev/null || true
	fi

	# Monta comando zpool create baseado no tipo
	local zpool_args=()
	case "$pool_type" in
	stripe)
		# Sem vdev type - apenas lista de dispositivos
		zpool_args=("${devices[@]}")
		;;
	mirror)
		zpool_args=("mirror" "${devices[@]}")
		;;
	raidz1)
		zpool_args=("raidz1" "${devices[@]}")
		;;
	raidz2)
		zpool_args=("raidz2" "${devices[@]}")
		;;
	raidz3)
		zpool_args=("raidz3" "${devices[@]}")
		;;
	esac

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
		"$pool" "${zpool_args[@]}"
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
	echo "
	=== Teste de Configuração ZFS ===

	Funções disponíveis:
	  zfs_create_pool <device> [pool_name]
	  zfs_create_datasets [pool_name]
	  zfs_export_pool [pool_name]
	  zfs_pool_exists [pool_name]
	"
fi
