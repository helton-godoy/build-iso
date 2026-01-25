#!/usr/bin/env bash
#
# components/03-pool.sh - ZFS pool creation with profile-specific logic
# Modularized from install-system
# Uses: lib/logging.sh, lib/chroot.sh
#
# [commit] feat: suporte robusto a criptografia nativa e múltiplas topologias ZFS
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

# Variáveis globais (serão importadas do orquestrador)
declare -a SELECTED_DISKS=()
declare RAID_TOPOLOGY=""
declare ASHIFT=12
declare COMPRESSION="zstd"
declare CHECKSUM="on"
declare COPIES=1
declare HDSIZE=""
declare POOL_NAME="zroot"
declare ENCRYPTION="off"
declare ENCRYPTION_PASSPHRASE=""
declare PROFILE="${PROFILE:-Server}"

# =============================================================================
# FUNÇÕES DE COLETA DE PARTIÇÕES
# =============================================================================

# Coletar partições ZFS de todos os discos
get_zfs_partitions() {
	local -a zfs_parts=()

	log_debug "Generating ZFS partition list for disks: ${SELECTED_DISKS[*]}"
	for disk in "${SELECTED_DISKS[@]}"; do
		[[ -z ${disk} ]] && continue
		local part_suffix
		part_suffix=$(get_part_suffix "${disk}")
		# Partição 2 agora é ZFS Root
		log_debug "Disk: ${disk}, Sufixo: ${part_suffix}, Partição: ${disk}${part_suffix}2"
		zfs_parts+=("${disk}${part_suffix}2")
	done

	for part in "${zfs_parts[@]}"; do
		echo "${part}"
	done
}

# Obter partição EFI do primeiro disco
get_efi_partition() {
	local disk=${SELECTED_DISKS[0]}
	local part_suffix
	part_suffix=$(get_part_suffix "${disk}")

	# Partição 1 agora é ESP
	echo "${disk}${part_suffix}1"
}

# Determinar sufixo de partição (para /dev/sdX vs /dev/nvme0n1)
get_part_suffix() {
	local disk=$1

	if [[ ${disk} =~ /dev/nvme ]]; then
		echo "p"
	else
		echo ""
	fi
}

# =============================================================================
# FUNÇÕES DE CRIAÇÃO DE POOL
# =============================================================================

# Preparar pool para recriação (remover pool existente)
prepare_pool_recreation() {
	local pool=$1

	log_init_component "Preparing ZFS Pool for Recreation"

	# Verificar se já existe pool com esse nome
	if zpool list "${pool}" >/dev/null 2>&1; then
		log "Pool ${pool} already exists, starting cleanup procedure..."

		# 1. Sincronizar todos os buffers
		sync

		# 2. Desabilitar swap se estiver em ZFS
		swapoff -a 2>>"${LOG_FILE}" || true

		# 3. Desmontagem recursiva do mountpoint com lazy unmount
		if [[ -d ${MOUNT_POINT} ]]; then
			log "Unmounting recursively ${MOUNT_POINT} (lazy)..."
			umount -Rl "${MOUNT_POINT}" 2>>"${LOG_FILE}" || true
			sleep 1
		fi

		# 4. Desmontar todos os datasets do pool (lazy)
		for ds in $(zfs list -H -o name -r "${pool}" 2>/dev/null | tac); do
			log "Unmounting dataset: ${ds}"
			zfs unmount -f "${ds}" 2>>"${LOG_FILE}" || true
		done

		# 5. Identificar processos usando o pool (informativo)
		if command -v lsof >/dev/null 2>&1; then
			local busy_procs
			busy_procs=$(lsof +D "${MOUNT_POINT}" 2>/dev/null || true)
			if [[ -n ${busy_procs} ]]; then
				log "Processes still using ${MOUNT_POINT}:"
				log "${busy_procs}"
			fi
		fi

		# 6. Tentar exportar com força
		log "Attempting to export pool ${pool}..."
		sync
		sleep 1
		if ! zpool export -f "${pool}" 2>>"${LOG_FILE}"; then
			log "First export attempt failed, waiting and trying again..."
			sleep 2
			sync
			zpool export -f "${pool}" 2>>"${LOG_FILE}" || true
		fi

		# 7. Se ainda existir, destruir forçadamente
		if zpool list "${pool}" >/dev/null 2>&1; then
			log "Pool still exists after export, attempting to destroy..."
			zpool destroy -f "${pool}" 2>>"${LOG_FILE}" || {
				log "CRITICAL ERROR: Unable to remove existing pool."
				log "The pool may be in use by another process."
				log "Try restarting the live system and running again."
				error_exit "Failed to remove existing pool. Restart the live system."
			}
		fi

		log "Old pool removed successfully."
	fi

	log_end_component "Preparing ZFS Pool for Recreation"
}

# Limpar labels ZFS existentes nas partições
clear_partition_labels() {
	log_info "Clearing ZFS partition labels..."

	mapfile -t zfs_parts < <(get_zfs_partitions)

	for part in "${zfs_parts[@]}"; do
		zpool labelclear -f "${part}" 2>>"${LOG_FILE}" || true
	done

	log_success "ZFS partition labels cleared"
}

# Criar pool ZFS com topologia e opções selecionadas
create_pool() {
	local -a zfs_parts=()
	mapfile -t zfs_parts < <(get_zfs_partitions)

	if [[ ${#zfs_parts[@]} -eq 0 ]]; then
		error_exit "Nenhuma partição ZFS encontrada. Verifique se os discos foram particionados corretamente."
	fi

	log "Partições ZFS detectadas: ${zfs_parts[*]}"

	log_init_component "Creating ZFS Pool (${RAID_TOPOLOGY})"

	# Limpar labels ZFS existentes nas partições
	clear_partition_labels

	# Comando base do zpool create
	local pool_cmd=(
		zpool create -f
		-o "ashift=${ASHIFT}"
		-o autotrim=on
		-O acltype=posixacl
		-O canmount=off
		-O "compression=${COMPRESSION}"
		-O dnodesize=auto
		-O normalization=formD
		-O relatime=on
		-O xattr=sa
		-O mountpoint=none
		-O "checksum=${CHECKSUM}"
		-O "copies=${COPIES}"
		-R "${MOUNT_POINT}"
	)

	# Construir argumentos de topologia
	local -a topology_args=()
	case ${RAID_TOPOLOGY} in
	Single)
		topology_args+=("${POOL_NAME}" "${zfs_parts[0]}")
		;;
	Stripe)
		topology_args+=("${POOL_NAME}" "${zfs_parts[@]}")
		;;
	Mirror)
		topology_args+=("${POOL_NAME}" mirror "${zfs_parts[@]}")
		;;
	RAIDZ1)
		topology_args+=("${POOL_NAME}" raidz1 "${zfs_parts[@]}")
		;;
	RAIDZ2)
		topology_args+=("${POOL_NAME}" raidz2 "${zfs_parts[@]}")
		;;
	RAIDZ3)
		topology_args+=("${POOL_NAME}" raidz3 "${zfs_parts[@]}")
		;;
	*)
		log_warn "Unknown RAID topology: ${RAID_TOPOLOGY}, using Single"
		topology_args+=("${POOL_NAME}" "${zfs_parts[0]}")
		;;
	esac

	# Adicionar opções de criptografia se habilitado
	if [[ ${ENCRYPTION} == "on" ]]; then
		log "Enabling native ZFS encryption..."
		pool_cmd+=(
			-O encryption=aes-256-gcm
			-O keyformat=passphrase
			-O keylocation=prompt
		)

		# Executar com pipe para a senha
		sync
		# ui_spin is hard with pipes, stick to manual or wrapping just the command?
		# Encryption prompt is tricky: zpool create -O keylocation=prompt asks on stdin.
		# But we are piping properly: echo "pass" | zpool ...
		# Spinners hide prompt? But if we provide input via pipe, it should be fine.
		# However, gum spin consumes stdin?? No, it consumes command output?
		# "gum spin -- command" runs command. Standard Input to gum spin *might* be swallowed or not passed.
		# It's safer to NOT use spin for critical input piping unless verified.
		# Let's verify `gum spin` behavior. `echo foo | gum spin -- cat` -> gum spin might grab stty.
		# SAFE CHOICE: Do not spin on encrypted creation to avoid pipe issues.
		if ! echo "${ENCRYPTION_PASSPHRASE}" | "${pool_cmd[@]}" "${topology_args[@]}" 2>>"${LOG_FILE}"; then
			error_exit "Falha ao criar pool ZFS criptografado. Verifique ${LOG_FILE}."
		fi
	else
		log "Executing zpool create: ${pool_cmd[*]} ${topology_args[*]}"
		sync
		if ! ui_spin "Creating ZFS Pool '${POOL_NAME}'" "${pool_cmd[@]}" "${topology_args[@]}" 2>>"${LOG_FILE}"; then
			error_exit "Falha ao criar pool ZFS. Verifique ${LOG_FILE}."
		fi
	fi

	# Configurar cachefile para garantir importação correta no boot
	# ui_spin "Setting zpool cachefile" ... (too fast to matter much, but consistency)
	zpool set cachefile=/etc/zfs/zpool.cache "${POOL_NAME}" 2>>"${LOG_FILE}" || true

	log "Pool ZFS '${POOL_NAME}' criado com sucesso em ${RAID_TOPOLOGY}"
	ui_alert "SUCCESS" "ZFS Pool created: ${POOL_NAME} (${RAID_TOPOLOGY})" "success"

	sync
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
	log_section "=== DEBIAN_ZFS Installer - ZFS Pool Creation ==="
	log_info "Creating ZFS pool for ${PROFILE^^} profile..."

	# Preparar pool para recriação se necessário
	prepare_pool_recreation "${POOL_NAME}"

	# Criar pool
	create_pool

	log_success "=== ZFS Pool Creation Completed ==="
	return 0
}

# Executar main se script for executado diretamente
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
	main "$@"
fi
