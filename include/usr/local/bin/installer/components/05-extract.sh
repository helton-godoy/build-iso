#!/usr/bin/env bash
#
# components/05-extract.sh - System extraction from squashfs
# Modularized from install-system
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
declare MOUNT_POINT="${MOUNT_POINT:-/mnt/target}"
declare SQUASHFS_PATH=""
declare SQUASHFS_DIR=""

# =============================================================================
# FUNÇÕES DE EXTRAÇÃO
# =============================================================================

# Criar diretórios essenciais no sistema de destino
create_essential_dirs() {
	log_info "Creating essential directories in ${MOUNT_POINT}..."

	mkdir -p "${MOUNT_POINT}" || error_exit "Falha ao criar diretório ${MOUNT_POINT}"
	mkdir -p "${MOUNT_POINT}/dev" || error_exit "Falha ao criar ${MOUNT_POINT}/dev"
	mkdir -p "${MOUNT_POINT}/proc" || error_exit "Falha ao criar ${MOUNT_POINT}/proc"
	mkdir -p "${MOUNT_POINT}/sys" || error_exit "Falha ao criar ${MOUNT_POINT}/sys"
	mkdir -p "${MOUNT_POINT}/run" || error_exit "Falha ao criar ${MOUNT_POINT}/run"
	mkdir -p "${MOUNT_POINT}/tmp" || error_exit "Falha ao criar ${MOUNT_POINT}/tmp"

	# Permissões especiais para /tmp
	chmod 1777 "${MOUNT_POINT}/tmp" || error_exit "Falha ao definir permissões em ${MOUNT_POINT}/tmp"

	log_success "Essential directories created"
}

# Validar existência do arquivo squashfs
validate_squashfs() {
	log_info "Validating squashfs file..."

	local squashfs_paths=(
		"/run/live/medium/live/00-core.squashfs"
		"/lib/live/mount/medium/live/00-core.squashfs"
		"/cdrom/live/00-core.squashfs"
		"/run/live/medium/live/filesystem.squashfs"
	)

	local found_path=""

	for path in "${squashfs_paths[@]}"; do
		if [[ -f ${path} ]]; then
			found_path="${path}"
			log_info "Squashfs found at: ${found_path}"
			break
		fi
	done

	if [[ -z ${found_path} ]]; then
		log_error "Squashfs file not found in any expected location"
		return 1
	fi

	# Exportar caminho encontrado
	export SQUASHFS_PATH="${found_path}"
	log_success "Squashfs file validated: ${SQUASHFS_PATH}"
	return 0
}

# Validar extração e criar arquivo de snapshot inicial
validate_and_create_snapshot() {
	log_info "Validating extraction and creating initial snapshot..."

	# Verificar arquivos críticos foram extraídos
	local critical_files=("${MOUNT_POINT}/bin/bash" "${MOUNT_POINT}/etc/passwd" "${MOUNT_POINT}/usr/bin")
	local missing_files=()

	for file in "${critical_files[@]}"; do
		if [[ ! -e ${file} ]]; then
			missing_files+=("${file}")
		fi
	done

	if [[ ${#missing_files[@]} -gt 0 ]]; then
		log_warn "Some critical files missing after extraction: ${missing_files[*]}"
	fi

	# Criar snapshot inicial do sistema instalado (usado por ZFSBootMenu)
	local snapshot="${MOUNT_POINT}/.snapshot"
	if [[ -d ${snapshot} ]]; then
		log_warn "Snapshot directory already exists at ${snapshot}, skipping creation"
	else
		log_info "Creating initial snapshot at ${snapshot}..."
		mkdir -p "${snapshot}" || error_exit "Falha ao criar diretório ${snapshot}"
	fi

	log_success "Extraction validated and snapshot created"
}

# Extrair uma camada específica do squashfs
extract_layer() {
	local layer_file="$1"
	local layer_name="$2"

	if [[ ! -f ${layer_file} ]]; then
		log_warn "Layer ${layer_name} not found at ${layer_file}, skipping."
		return 0
	fi

	log_info "Extracting layer: ${layer_name} from ${layer_file}..."

	# Extrair camada com unsquashfs
	local log_tmp
	log_tmp=$(mktemp)

	if ! gum spin --spinner dot --title "Extracting layer ${layer_name}..." -- \
		bash -c "unsquashfs -f -n -d '${MOUNT_POINT}' '${layer_file}' </dev/null > '${log_tmp}' 2>&1"; then
		log_error "Failed to extract layer ${layer_name}"
		cat "${log_tmp}" >>"${LOG_FILE}"
		rm -f "${log_tmp}"
		return 1
	fi

	cat "${log_tmp}" >>"${LOG_FILE}"
	rm -f "${log_tmp}"

	log_success "Layer ${layer_name} extracted successfully"
}

# Extrair sistema base completo (todas as camadas)
extract_full_system() {
	log_init_component "Extracting Full System from Squashfs"

	# Validar squashfs
	validate_squashfs || return 1

	# Extrair base (00-core.squashfs)
	extract_layer "${SQUASHFS_PATH}" "Core System"

	# Diretório onde se encontrou o squashfs
	SQUASHFS_DIR=$(dirname "${SQUASHFS_PATH}")

	# Se estivermos em perfil WORKSTATION, extrair também camadas adicionais
	if [[ ${PROFILE} == "Workstation" ]]; then
		# Camadas WORKSTATION: buscar por padrão
		local workstation_layers=(
			"${SQUASHFS_DIR}/10-server.squashfs"
			"${SQUASHFS_DIR}/20-workstation.squashfs"
		)

		for layer in "${workstation_layers[@]}"; do
			if [[ -f ${layer} ]]; then
				extract_layer "${layer}" "Workstation Layer"
			fi
		done
	fi

	# Validar e criar snapshot
	validate_and_create_snapshot || return 1

	# Copiar zpool.cache para o sistema instalado
	if [[ -f "/etc/zfs/zpool.cache" ]]; then
		mkdir -p "${MOUNT_POINT}/etc/zfs" || log_warn "Failed to create zpool.cache directory"
		cp /etc/zfs/zpool.cache "${MOUNT_POINT}/etc/zfs/" || log_warn "Failed to copy zpool.cache"
		log_info "zpool.cache copied to ${MOUNT_POINT}/etc/zfs/"
	fi

	log_end_component "Extracting Full System"
	return 0
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
	log_section "=== DEBIAN_ZFS Installer - System Extraction Phase ==="
	log_info "Extracting system from squashfs for ${PROFILE^^} profile..."

	# Criar diretórios essenciais
	create_essential_dirs

	# Extrair sistema completo
	if ! extract_full_system; then
		log_error "Failed to extract system from squashfs"
		return 1
	fi

	log_success "=== System extraction completed successfully ==="
	return 0
}

# Executar main se script for executado diretamente
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
	main "$@"
fi
