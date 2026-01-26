#!/usr/bin/env bash
#
# lib/chroot.sh - Wrapper Chroot com limpeza automática para DEBIAN_ZFS Installer
# Baseado em estratégias di-live
#

set -euo pipefail

# Variáveis globais (podem ser sobrescritas)
declare -g CHROOT_MOUNTS=()
CHROOT_EXITCODE=0

# =============================================================================
# FUNÇÕES PÚBLICAS
# =============================================================================

# Executar comando em chroot com gerenciamento automático de mounts
# Uso: chroot_zfs /mnt/target comando arg1 arg2
chroot_zfs() {
	local target=$1
	shift
	local command=("$@")

	# Validar target
	if [[ ! -d ${target} ]]; then
		source "${LIB_DIR}/logging.sh"
		log_error "Target não é um diretório válido: ${target}"
		return 1
	fi

	# Garantir que target está montado
	if ! mountpoint -q "${target}"; then
		source "${LIB_DIR}/logging.sh"
		log_warn "Target ${target} não está montado, prosseguindo mesmo assim"
	fi

	# Montar sistemas de arquivos virtuais
	_mount_virtual_filesystems "${target}"
	CHROOT_MOUNTS+=("$(ls -d "${target}"/{dev,proc,sys,run} 2>/dev/null)")

	source "${LIB_DIR}/logging.sh"
	log_debug "Executando em chroot ${target}: ${command[*]}"

	# Executar comando em chroot com ambiente controlado
	HOME=/root \
		TERM="${TERM:-dumb}" \
		LC_ALL=C \
		PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
		DEBIAN_FRONTEND=noninteractive \
		DEBIAN_PRIORITY=critical \
		chroot "${target}" "${command[@]}"

	CHROOT_EXITCODE=$?

	# Verificar resultado
	if [[ ${CHROOT_EXITCODE} -ne 0 ]]; then
		log_debug "Chroot command failed with exit code ${CHROOT_EXITCODE}"
	else
		log_debug "Chroot command succeeded"
	fi

	return "${CHROOT_EXITCODE}"
}

# Executar comando em chroot silencioso (sem output no terminal)
# Uso: chroot_zfs_silent /mnt/target comando
chroot_zfs_silent() {
	local target=$1
	shift
	local command=("$@")

	# Montar sistemas de arquivos virtuais
	_mount_virtual_filesystems "${target}"
	CHROOT_MOUNTS+=("$(ls -d "${target}"/{dev,proc,sys,run} 2>/dev/null)")

	source "${LIB_DIR}/logging.sh"
	log_debug "Executando silencioso em chroot ${target}: ${command[*]}"

	# Executar em chroot redirecionando output para log
	HOME=/root \
		TERM=dumb \
		LC_ALL=C \
		PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
		DEBIAN_FRONTEND=noninteractive \
		DEBIAN_PRIORITY=critical \
		chroot "${target}" "${command[@]}" >>"${LOG_FILE}" 2>&1

	CHROOT_EXITCODE=$?

	return "${CHROOT_EXITCODE}"
}

# Executar múltiplos comandos em chroot (pára de executar wrapper múltiplos)
# Uso: chroot_zfs_batch /mnt/target comando1 && comando2 && comando3
chroot_zfs_batch() {
	local target=$1
	shift
	local commands=("$@")

	_mount_virtual_filesystems "${target}"
	CHROOT_MOUNTS+=("$(ls -d "${target}"/{dev,proc,sys,run} 2>/dev/null)")

	source "${LIB_DIR}/logging.sh"
	log_debug "Executando batch em chroot ${target}"

	for cmd in "${commands[@]}"; do
		log_debug "  Executando: ${cmd}"
		HOME=/root \
			TERM=dumb \
			LC_ALL=C \
			PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
			DEBIAN_FRONTEND=noninteractive \
			DEBIAN_PRIORITY=critical \
			chroot "${target}" bash -c "${cmd}" >>"${LOG_FILE}" 2>&1
		local exitcode=$?
		if [[ ${exitcode} -ne 0 ]]; then
			log_error "Batch command failed with exit code ${exitcode}: ${cmd}"
		fi
	done
}

# Executar comando em chroot e capturar output
# Uso: chroot_zfs_capture /mnt/target comando
chroot_zfs_capture() {
	local target=$1
	shift
	local command=("$@")

	_mount_virtual_filesystems "${target}"
	CHROOT_MOUNTS+=("$(ls -d "${target}"/{dev,proc,sys,run} 2>/dev/null)")

	source "${LIB_DIR}/logging.sh"
	log_debug "Capturando output de chroot ${target}: ${command[*]}"

	# Executar e capturar stdout
	local output
	output=$(HOME=/root \
		TERM=dumb \
		LC_ALL=C \
		PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
		DEBIAN_FRONTEND=noninteractive \
		DEBIAN_PRIORITY=critical \
		chroot "${target}" "${command[@]}" 2>&1)

	CHROOT_EXITCODE=$?

	echo "${output}"

	return "${CHROOT_EXITCODE}"
}

# =============================================================================
# FUNÇÕES PRIVADAS
# =============================================================================

# Montar sistemas de arquivos virtuais no target
_mount_virtual_filesystems() {
	local target=$1

	local mounts=()

	# /dev
	if ! mountpoint -q "${target}/dev" 2>/dev/null; then
		if ! mount --make-private --rbind /dev "${target}/dev" 2>/dev/null; then
			mounts+=("dev")
		fi
	fi

	# /proc
	if ! mountpoint -q "${target}/proc" 2>/dev/null; then
		if ! mount --make-private --rbind /proc "${target}/proc" 2>/dev/null; then
			mounts+=("proc")
		fi
	fi

	# /sys
	if ! mountpoint -q "${target}/sys" 2>/dev/null; then
		if ! mount --make-private --rbind /sys "${target}/sys" 2>/dev/null; then
			mounts+=("sys")
		fi
	fi

	# /run
	if ! mountpoint -q "${target}/run" 2>/dev/null; then
		if ! mount --make-private --rbind /run "${target}/run" 2>/dev/null; then
			mounts+=("run")
		fi
	fi

	# Criar diretórios se não existirem
	for dir in dev proc sys run; do
		if [[ ! -d "${target}/${dir}" ]]; then
			mkdir -p "${target}/${dir}" 2>/dev/null || true
		fi
	done

	if [[ ${#mounts[@]} -gt 0 ]]; then
		log_debug "Mounted virtual filesystems: ${mounts[*]}"
	fi
}

# Desmontar sistemas de arquivos virtuais
_unmount_virtual_filesystems() {
	local target=$1
	local mount_order=(run sys proc dev) # Ordem inversa para desmontar em ordem correta

	for dir in "${mount_order[@]}"; do
		local mountpoint="${target}/${dir}"
		if mountpoint -q "${mountpoint}" 2>/dev/null; then
			log_debug "Unmounting ${mountpoint}"
			umount -l "${mountpoint}" 2>/dev/null || true
		fi
	done
}

# Limpar todos os mounts criados
_cleanup_all_mounts() {
	log_debug "Cleaning up all chroot mounts..."

	# Desmontar em ordem inversa de criação
	for mountpoint in "${CHROOT_MOUNTS[@]}"; do
		if mountpoint -q "${mountpoint}" 2>/dev/null; then
			log_debug "  Unmounting ${mountpoint}"
			umount -l "${mountpoint}" 2>/dev/null || true
		fi
	done

	CHROOT_MOUNTS=()
}

# =============================================================================
# LIMPEZA AUTOMÁTICA
# =============================================================================

# Função de limpeza executada em saída
cleanup() {
	_cleanup_all_mounts
}

# Registrar cleanup para ser executado em EXIT
trap cleanup EXIT

# =============================================================================
# INICIALIZAÇÃO
# =============================================================================

# Detectar diretório de bibliotecas se não estiver definido
if [[ -z "${LIB_DIR:-}" ]]; then
	LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/"
	export LIB_DIR
fi

# Variável de log (se não estiver definida)
LOG_FILE="${LOG_FILE:-/var/log/debian_zfs_installer.log}"

# Verificar logging.sh
if [[ -f "${LIB_DIR}/logging.sh" ]]; then
	source "${LIB_DIR}/logging.sh"
else
	echo "WARNING: logging.sh não encontrado em ${LIB_DIR}" >&2
fi

# Inicializar logging se disponível
if command -v log_init &>/dev/null; then
	log_init 2>/dev/null || true
fi

log_debug "Biblioteca chroot.sh inicializada"
