#!/usr/bin/env bash
#
# components/01-validate.sh - Validations and preflight checks for DEBIAN_ZFS Installer
# Modularized from install-system
# Uses: lib/logging.sh, lib/validation.sh
#
# [commit] fix: ajuste no path do MBR para suportar testes unitários
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

# =============================================================================
# FUNÇÕES DE VALIDAÇÃO ESPECÍFICAS DO INSTALADOR
# =============================================================================

# Verificar pré-requisitos completos do instalador
# Esta função substitui todas as funções de pré-requisito do install-system original
run_installer_validations() {
	log_init_component "Validating Installer Environment"

	# 1. Validar root
	validate_root || return 1

	# 2. Validar memória
	validate_memory || return 1

	# 3. Validar módulo ZFS
	validate_zfs_module || return 1

	# 4. Validar comandos ZFS
	validate_zfs_commands || return 1

	# 5. Validar firmware (UEFI/BIOS)
	local firmware
	firmware=$(validate_firmware)
	log_info "Firmware: ${firmware^^}"

	# 6. Validar comandos necessários
	local commands=(
		"gum"
		"wipefs"
		"sgdisk"
		"mkfs.vfat"
		"efibootmgr"
		"unsquashfs"
		"rsync"
		"syslinux"
		"dd"
	)
	validate_commands "${commands[@]}" || return 1

	# 7. Verificar syslinux gptmbr.bin
	local mbr_path="${SYSLINUX_MBR:-/usr/lib/syslinux/mbr/gptmbr.bin}"
	if [[ ! -f ${mbr_path} ]]; then
		log_error "Arquivo MBR não encontrado: ${mbr_path}. Instale syslinux-common."
		return 1
	fi

	log_success "All validations passed"
	return 0
}

# Validar ambiente para instalação de perfil específico
# Uso: validate_profile_environment Server|Workstation
validate_profile_environment() {
	local profile=$1

	log_init_component "Validating Environment for ${profile^^} Profile"

	# Validar perfil
	validate_profile "${profile}" || return 1

	# Validações básicas
	validate_root || return 1
	validate_memory || return 1
	validate_zfs_module || return 1
	validate_zfs_commands || return 1

	log_success "Profile ${profile^^} environment validated"
	return 0
}

# Validar pré-requisitos para operações ZFS
# Uso: validate_zfs_prerequisites zroot
validate_zfs_env() {
	local pool_name="${1:-zroot}"

	log_init_component "Validating ZFS Prerequisites for ${pool_name}"

	# Validar módulo
	validate_zfs_module || return 1

	# Validar comandos ZFS
	validate_zfs_commands || return 1

	# Verificar se pool já existe
	if zpool list "${pool_name}" >/dev/null 2>&1; then
		log_warn "Pool ZFS ${pool_name} already exists. Will be recreated if needed."
	fi

	log_success "ZFS prerequisites validated"
	return 0
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
	log_section "=== DEBIAN_ZFS Installer - Validation Phase ==="
	log_info "Running preflight checks..."

	# Executar todas as validações do instalador
	if ! run_installer_validations; then
		log_error "Validation failed. Installer cannot proceed."
		return 1
	fi

	log_success "=== All validations completed successfully ==="
	return 0
}

# Executar main se script for executado diretamente
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
	main "$@"
fi
