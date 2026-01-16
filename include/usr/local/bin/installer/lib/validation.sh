#!/usr/bin/env bash
#
# lib/validation.sh - Biblioteca de validação para DEBIAN_ZFS Installer
# Baseado em estratégias di-live
#

set -euo pipefail

# =============================================================================
# VARIÁVEIS GLOBAIS
# =============================================================================

# Tamanho mínimo de disco em GB (pode ser sobreescrito via env)
MIN_DISK_GB="${MIN_DISK_GB:-20}"

# Memória mínima em GB
MIN_MEM_GB=2

# Tamanho mínimo de partição ESP em MB
MIN_ESP_MB="${MIN_ESP_MB:-128}"

# Array de discos validados
declare -a VALIDATED_DISKS=()

# =============================================================================
# FUNÇÕES DE VALIDAÇÃO
# =============================================================================

# Validar se está rodando como root
# Uso: validate_root
validate_root() {
	if [[ ${EUID} -ne 0 ]]; then
		source "${LIB_DIR}/logging.sh"
		log_error "Este script precisa ser executado como root."
		return 1
	fi
	log_debug "Verificação de root: OK"
	return 0
}

# Validar comando existe
# Uso: validate_command <comando> [descrição]
validate_command() {
	local cmd=$1
	local description="${2:-comando ${cmd}}"

	if ! command -v "${cmd}" >/dev/null 2>&1; then
		source "${LIB_DIR}/logging.sh"
		log_error "Comando não encontrado: ${cmd} (${description})"
		return 1
	fi

	log_debug "Comando ${cmd} verificado: OK"
	return 0
}

# Validar múltiplos comandos
# Uso: validate_commands comando1 comando2 comando3
validate_commands() {
	local commands=("$@")
	local missing=()

	for cmd in "${commands[@]}"; do
		if ! command -v "${cmd}" >/dev/null 2>&1; then
			missing+=("${cmd}")
		fi
	done

	if [[ ${#missing[@]} -gt 0 ]]; then
		source "${LIB_DIR}/logging.sh"
		log_error "Comandos necessários não encontrados: ${missing[*]}"
		return 1
	fi

	log_debug "Comandos ${commands[*]} verificados: OK"
	return 0
}

# Validar disco (tamanho, tipo, acessibilidade)
# Uso: validate_disk /dev/sdX
validate_disk() {
	local disk=$1

	source "${LIB_DIR}/logging.sh"
	log_debug "Validando disco: ${disk}"

	# Verificar se disco existe
	if [[ ! -b "${disk}" ]]; then
		log_error "Disco não encontrado: ${disk}"
		return 1
	fi

	# Verificar tamanho mínimo
	local size_gb
	size_gb=$(lsblk -b -o SIZE -n -d "${disk}" | awk '{printf "%.0f", $1/1024/1024/1024}')

	if ((size_gb < MIN_DISK_GB)); then
		log_error "Disco ${disk} muito pequeno: ${size_gb}GB < mínimo ${MIN_DISK_GB}GB"
		return 1
	fi

	# Verificar se é disco bloqueado (ex: /dev/sr0, /dev/loop*)
	if lsblk -d -n -o ROTA -d "${disk}" | grep -q 1; then
		log_warn "Disco ${disk} é rotativo (HDD/SSD)"
	else
		log_debug "Disco ${disk} não é rotativo (pode ser NVMe/Virtual)"
	fi

	# Validar disco e adicionar à lista
	VALIDATED_DISKS+=("${disk}")
	log_debug "Disco ${disk} validado: ${size_gb}GB"

	return 0
}

# Validar múltiplos discos
# Uso: validate_disks /dev/sdX /dev/sdY
validate_disks() {
	local disks=("$@")

	source "${LIB_DIR}/logging.sh"
	log_debug "Validando ${#disks[@]} discos: ${disks[*]}"

	# Limpar lista
	VALIDATED_DISKS=()

	# Validar cada disco
	for disk in "${disks[@]}"; do
		if ! validate_disk "${disk}"; then
			return 1
		fi
	done

	log_info "Todos os discos validados com sucesso"
	return 0
}

# Validar memória disponível
# Uso: validate_memory
validate_memory() {
	source "${LIB_DIR}/logging.sh"
	log_debug "Validando memória..."

	local mem_kb mem_gb
	mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
	mem_gb=$((mem_kb / 1024 / 1024))

	log_debug "Memória detectada: ${mem_gb}GB"

	if [[ ${mem_gb} -lt ${MIN_MEM_GB} ]]; then
		log_warn "Memória baixa detectada (${mem_gb}GB < mínimo ${MIN_MEM_GB}GB)"
		log_warn "ZFS recomenda no mínimo ${MIN_MEM_GB}GB de RAM"
		# Retornar warning mas não falhar
		return 0
	fi

	log_debug "Memória OK: ${mem_gb}GB >= ${MIN_MEM_GB}GB"
	return 0
}

# Validar módulo ZFS carregado
# Uso: validate_zfs_module
validate_zfs_module() {
	source "${LIB_DIR}/logging.sh"
	log_debug "Validando módulo ZFS..."

	# Verificar via /sys/module
	if [[ ! -d /sys/module/zfs ]]; then
		log_error "Módulo ZFS não carregado (/sys/module/zfs não existe)"
		return 1
	fi

	# Verificar via /proc/modules
	if ! grep -qw "^zfs$" /proc/modules; then
		log_error "Módulo ZFS não encontrado em /proc/modules"
		return 1
	fi

	log_debug "Módulo ZFS carregado: OK"
	return 0
}

# Validar comandos ZFS (zpool, zfs)
# Uso: validate_zfs_commands
validate_zfs_commands() {
	source "${LIB_DIR}/logging.sh"

	# Verificar zpool
	if ! command -v zpool >/dev/null 2>&1; then
		log_error "Comando zpool não encontrado. Instale zfsutils-linux"
		return 1
	fi

	# Verificar zfs
	if ! command -v zfs >/dev/null 2>&1; then
		log_error "Comando zfs não encontrado. Instale zfsutils-linux"
		return 1
	fi

	log_debug "Comandos ZFS verificados: OK"

	# Testar funcionalidade
	if ! zpool version >/dev/null 2>&1; then
		log_warn "zpool version não funcionou. ZFS pode estar corrompido."
		return 0
	fi

	log_debug "Teste zpool version: OK"
	return 0
}

# Validar firmware (UEFI vs BIOS)
# Uso: validate_firmware
validate_firmware() {
	source "${LIB_DIR}/logging.sh"

	if [[ -d /sys/firmware/efi ]]; then
		log_debug "Firmware: UEFI detectado"
		echo "uefi"
		return 0
	else
		log_debug "Firmware: BIOS (Legacy) detectado"
		echo "bios"
		return 0
	fi
}

# Validar conexão de rede (opcional)
# Uso: validate_network [obrigatório]
validate_network() {
	local required="${1:-false}"

	source "${LIB_DIR}/logging.sh"

	# Verificar conectividade básica
	if ! ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
		if [[ "${required}" == "true" ]]; then
			log_error "Conexão de rede não disponível mas é obrigatória"
			return 1
		else
			log_warn "Conexão de rede não disponível (opcional)"
			return 0
		fi
	else
		log_debug "Conexão de rede OK"
		return 0
	fi
}

# Validar arquivo ou diretório existe
# Uso: validate_path <path> [descrição] [directory|file]
validate_path() {
	local path=$1
	local description="${2:-${path}}"
	local type="${3:-auto}"

	source "${LIB_DIR}/logging.sh"

	if [[ "${type}" == "directory" ]]; then
		if [[ ! -d "${path}" ]]; then
			log_error "Diretório não encontrado: ${path} (${description})"
			return 1
		fi
	elif [[ "${type}" == "file" ]]; then
		if [[ ! -f "${path}" ]]; then
			log_error "Arquivo não encontrado: ${path} (${description})"
			return 1
		fi
	else
		if [[ ! -e "${path}" ]]; then
			log_error "Caminho não encontrado: ${path} (${description})"
			return 1
		fi
	fi

	log_debug "Caminho ${path} validado: OK"
	return 0
}

# =============================================================================
# FUNÇÕES DE VALIDAÇÃO DE DADOS
# =============================================================================

# Validar hostname
# Uso: validate_hostname <hostname>
validate_hostname() {
	local hostname=$1

	source "${LIB_DIR}/logging.sh"

	# Validação básica
	if [[ -z "${hostname}" ]]; then
		log_error "Hostname não pode ser vazio"
		return 1
	fi

	# Tamanho máximo (FQDN)
	if [[ ${#hostname} -gt 253 ]]; then
		log_error "Hostname muito longo (máx 253 caracteres)"
		return 1
	fi

	# Caracteres válidos
	if [[ ! "${hostname}" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
		log_error "Hostname contém caracteres inválidos"
		return 1
	fi

	log_debug "Hostname ${hostname} validado: OK"
	return 0
}

# Validar nome de usuário
# Uso: validate_username <username>
validate_username() {
	local username=$1

	source "${LIB_DIR}/logging.sh"

	if [[ -z "${username}" ]]; then
		log_error "Nome de usuário não pode ser vazio"
		return 1
	fi

	# Não pode começar com número
	if [[ "${username}" =~ ^[0-9] ]]; then
		log_error "Nome de usuário não pode começar com número"
		return 1
	fi

	# Apenas letras, números, hífens e undescores
	if [[ ! "${username}" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
		log_error "Nome de usuário contém caracteres inválidos"
		return 1
	fi

	# Tamanho máximo (32 caracteres)
	if [[ ${#username} -gt 32 ]]; then
		log_error "Nome de usuário muito longo (máx 32 caracteres)"
		return 1
	fi

	log_debug "Nome de usuário ${username} validado: OK"
	return 0
}

# Validar senha
# Uso: validate_password <senha> <senha_confirm> [min_len]
validate_password() {
	local password=$1
	local password_confirm="${2:-}"
	local min_len="${3:-6}"

	source "${LIB_DIR}/logging.sh"

	# Verificar se senhas coincidem
	if [[ -n "${password_confirm}" ]] && [[ "${password}" != "${password_confirm}" ]]; then
		log_error "Senhas não coincidem"
		return 1
	fi

	# Tamanho mínimo
	if [[ ${#password} -lt ${min_len} ]]; then
		log_error "Senha muito curta (mínimo ${min_len} caracteres)"
		return 1
	fi

	# Tamanho máximo razoável
	if [[ ${#password} -gt 128 ]]; then
		log_error "Senha muito longa (máx 128 caracteres)"
		return 1
	fi

	log_debug "Senha validada: OK"
	return 0
}

# Validar passphrase (para criptografia)
# Uso: validate_passphrase <passphrase> <passphrase_confirm>
validate_passphrase() {
	local passphrase=$1
	local passphrase_confirm="${2:-}"

	source "${LIB_DIR}/logging.sh"

	# Validação básica
	if [[ -z "${passphrase}" ]]; then
		log_error "Passphrase não pode ser vazia"
		return 1
	fi

	# Verificar se coincidem
	if [[ -n "${passphrase_confirm}" ]] && [[ "${passphrase}" != "${passphrase_confirm}" ]]; then
		log_error "Passphrases não coincidem"
		return 1
	fi

	# Tamanho mínimo (requisito ZFS: 8 caracteres)
	if [[ ${#passphrase} -lt 8 ]]; then
		log_error "Passphrase muito curta (mínimo 8 caracteres para criptografia ZFS)"
		return 1
	fi

	log_debug "Passphrase validada: OK"
	return 0
}

# =============================================================================
# FUNÇÕES DE VALIDAÇÃO DE PERFIL
# =============================================================================

# Validar nome do perfil
# Uso: validate_profile <server|workstation|minimal>
validate_profile() {
	local profile=$1

	source "${LIB_DIR}/logging.sh"

	local valid_profiles=("Server" "Workstation" "Minimal")

	if [[ ! " ${valid_profiles[*]} " =~ " ${profile} " ]]; then
		log_error "Perfil inválido: ${profile}. Perfis válidos: ${valid_profiles[*]}"
		return 1
	fi

	log_debug "Perfil ${profile} validado: OK"
	return 0
}

# Obter perfil padrão se não especificado
# Uso: get_default_profile
get_default_profile() {
	echo "Server" # Server é padrão para servidores
}

# =============================================================================
# FUNÇÕES DE VALIDAÇÃO COMPLETA
# =============================================================================

# Executar todas as validações básicas do instalador
# Uso: validate_installer_environment
validate_installer_environment() {
	source "${LIB_DIR}/logging.sh"

	log_init_component "Validando Ambiente do Instalador"

	# 1. Root
	validate_root || return 1

	# 2. Memória
	validate_memory

	# 3. ZFS
	validate_zfs_module || return 1
	validate_zfs_commands || return 1

	# 4. Firmware
	validate_firmware >/dev/null

	# 5. Comandos básicos
	validate_commands wipefs sgdisk mkfs.vfat partprobe || return 1

	log_end_component "Validando Ambiente do Instalador"
	return 0
}

# Validar pré-requisitos para operações ZFS
# Uso: validate_zfs_prerequisites <pool_name>
validate_zfs_prerequisites() {
	local pool_name=$1

	source "${LIB_DIR}/logging.sh"
	log_init_component "Validando Pré-requisitos ZFS para ${pool_name}"

	# Verificar módulo
	validate_zfs_module || return 1

	# Verificar comandos
	validate_zfs_commands || return 1

	# Verificar se pool já existe
	if zpool list "${pool_name}" >/dev/null 2>&1; then
		log_warn "Pool ZFS ${pool_name} já existe. Será recriado se necessário."
	fi

	log_end_component "Validando Pré-requisitos ZFS"
	return 0
}

# =============================================================================
# INICIALIZAÇÃO
# =============================================================================

# Detectar diretório de bibliotecas
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/"
export LIB_DIR

# Carregar logging se disponível
if [[ -f "${LIB_DIR}/logging.sh" ]]; then
	source "${LIB_DIR}/logging.sh"
else
	echo "WARNING: logging.sh não encontrado em ${LIB_DIR}" >&2
fi

# Inicializar logging se disponível
if command -v log_init &>/dev/null; then
	log_init 2>/dev/null || true
fi

log_debug "Biblioteca validation.sh inicializada"
