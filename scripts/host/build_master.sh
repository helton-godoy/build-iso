#!/bin/bash
# =============================================================================
# build_master.sh - Orquestrador principal
# Executa no host (Deepin 25) e coordena todo o processo
# =============================================================================

set -euo pipefail

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VM_NAME="debian-iso-builder"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*" >&2; }
log_ok() { echo -e "${GREEN}[OK]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERRO]${NC} $*" >&2; }
log_step() { echo -e "${CYAN}[ETAPA]${NC} $*" >&2; }

# =============================================================================
# VERIFICAÇÕES
# =============================================================================

check_root() {
	if [[ ${EUID} -ne 0 ]]; then
		log_error "Execute como root: sudo $0"
		exit 1
	fi
}

check_host_setup() {
	log_info "Verificando configuração do host..."

	local missing=()

	for cmd in virsh virt-install virt-builder; do
		if ! command -v "${cmd}" &>/dev/null; then
			missing+=("${cmd}")
		fi
	done

	if [[ ${#missing[@]} -gt 0 ]]; then
		log_warn "Ferramentas faltando: ${missing[*]}"
		log_info "Executando setup do host..."
		bash "${SCRIPT_DIR}/setup_host.sh"
	else
		log_ok "Host configurado"
	fi
}

# =============================================================================
# VM MANAGEMENT
# =============================================================================

ensure_vm_running() {
	log_info "Verificando VM..."

	# Verificar se VM existe
	if ! virsh list --all | grep -q "${VM_NAME}"; then
		log_info "VM não existe. Criando..."
		bash "${SCRIPT_DIR}/create_vm.sh"
		return
	fi

	# Verificar se está rodando
	if ! virsh list --state-running | grep -q "${VM_NAME}"; then
		log_info "Iniciando VM..."
		virsh start "${VM_NAME}"
		sleep 30
	fi

	log_ok "VM está rodando"
}

get_vm_ip() {
	log_info "Buscando IPs da VM..."
	local ips
	# Coleta todos os IPs únicos reportados pelo libvirt
	ips=$(virsh domifaddr "${VM_NAME}" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u || echo "")

	if [[ -z ${ips} ]]; then
		log_warn "Nenhum IP encontrado automaticamente via libvirt."
		return 1
	fi

	echo "${ips}"
	return 0
}

wait_for_ssh() {
	local ip_list="$1"
	local ssh_key="${PROJECT_ROOT}/.ssh/vm_key"

	while true; do
		if [[ -n ${ip_list} ]]; then
			log_info "Tentando conectar aos IPs detectados..."
			for ip in ${ip_list}; do
				log_info "Testando IP: ${ip} (timeout 5s)..."
				if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes \
					-i "${ssh_key}" root@"${ip}" "echo ok" &>/dev/null; then
					log_ok "Conexão estabelecida com sucesso através do IP: ${ip}"
					# Retorna apenas o IP limpo, sem espaços ou logs
					echo "${ip}" | tr -d '[:space:]'
					return 0
				fi
				log_warn "Falha na conexão com ${ip}"
			done
		fi

		echo "" >&2 # Log para stderr
		log_error "Não foi possível conectar a nenhum IP detectado automaticamente." >&2
		echo -e "${YELLOW}Por favor, verifique o IP no Virt-Manager e informe-o manualmente.${NC}" >&2
		read -r -p "IP da VM (ou 'c' para cancelar): " manual_ip </dev/tty

		if [[ ${manual_ip} == "c" ]]; then
			log_error "Operação cancelada pelo usuário." >&2
			exit 1
		fi

		if [[ -n ${manual_ip} ]]; then
			log_info "Validando IP informado: ${manual_ip}..." >&2
			if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes \
				-i "${ssh_key}" root@"${manual_ip}" "echo ok" &>/dev/null; then
				log_ok "Conexão estabelecida com o IP manual: ${manual_ip}" >&2
				echo "${manual_ip}" | tr -d '[:space:]'
				return 0
			else
				log_error "Não foi possível conectar ao IP: ${manual_ip}" >&2
				ip_list="" # Limpa para a próxima iteração focar no manual
			fi
		fi
	done
}

# =============================================================================
# BUILD
# =============================================================================

copy_scripts_to_vm() {
	local vm_ip="$1"
	local ssh_key="${PROJECT_ROOT}/.ssh/vm_key"

	log_info "Copiando scripts para VM (${vm_ip})..."

	scp -o StrictHostKeyChecking=no -i "${ssh_key}" \
		"${PROJECT_ROOT}/scripts/vm/build_iso.sh" \
		root@"${vm_ip}":/root/

	ssh -o StrictHostKeyChecking=no -i "${ssh_key}" root@"${vm_ip}" \
		"chmod +x /root/build_iso.sh"

	log_ok "Scripts copiados"
}

run_build_in_vm() {
	local vm_ip="$1"
	local ssh_key="${PROJECT_ROOT}/.ssh/vm_key"

	log_info "Executando build na VM..."
	log_info "Este processo pode demorar 30-60 minutos..."

	# Executar ssh e tee, mas verificar o status do ssh
	# shellcheck disable=SC2312 # PIPESTATUS[0] handles the ssh exit code
	ssh -o StrictHostKeyChecking=no -i "${ssh_key}" root@"${vm_ip}" \
		"/root/build-iso/scripts/vm/build_iso.sh" 2>&1 | tee "${PROJECT_ROOT}/logs/build-$(date +%Y%m%d-%H%M%S).log"

	# Verificar o status de saída do primeiro comando no pipe (ssh)
	if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
		log_error "O build na VM falhou!"
		exit 1
	fi

	log_ok "Build concluído"
}

copy_iso_from_vm() {
	local vm_ip="$1"
	local ssh_key="${PROJECT_ROOT}/.ssh/vm_key"

	log_info "Copiando ISO da VM..."

	scp -o StrictHostKeyChecking=no -i "${ssh_key}" \
		"root@${vm_ip}:/root/output/*.iso" \
		"root@${vm_ip}:/root/output/*.sha256" \
		"${PROJECT_ROOT}/output/"

	log_ok "ISO copiada para: ${PROJECT_ROOT}/output/"
}

# =============================================================================
# CLEANUP
# =============================================================================

stop_vm() {
	log_info "Parando VM..."
	virsh shutdown "${VM_NAME}" 2>/dev/null || true
	log_ok "VM parada"
}

# =============================================================================
# HELP
# =============================================================================

show_help() {
	cat <<EOF
build_master.sh - Orquestrador de Build ISO Debian-ZFS

USAGE:
    sudo $0 [COMANDO]

COMANDOS:
    build       Executar build completo (padrão)
    only-build  Executar apenas o build na VM (sem desligar)
    setup       Apenas configurar host
    create-vm   Apenas criar VM
    status      Mostrar status da VM
    ssh         Conectar via SSH na VM
    stop        Parar VM
    destroy     Remover VM completamente
    help        Mostrar esta ajuda

EXEMPLOS:
    sudo $0 build     # Build completo
    sudo $0 status    # Ver status
    sudo $0 ssh       # Acessar VM

EOF
}

# =============================================================================
# COMANDOS
# =============================================================================

cmd_build() {
	log_step "1/5 - Verificando host"
	check_host_setup

	log_step "2/5 - Preparando VM"
	ensure_vm_running

	local ip_list
	# shellcheck disable=SC2310
	if ! ip_list=$(get_vm_ip); then ip_list=""; fi

	local vm_ip
	vm_ip=$(wait_for_ssh "${ip_list}")

	# log_step "3/5 - Copiando scripts"
	# Com Virtiofs mapeando o projeto, não precisamos mais do SCP para scripts
	# copy_scripts_to_vm "${vm_ip}"

	log_step "3/5 - Sincronizando scripts (via Virtiofs)"
	log_info "Scripts já disponíveis em /mnt/shared/build-iso/scripts/"

	log_step "4/5 - Executando build"
	run_build_in_vm "${vm_ip}"

	log_step "5/5 - Copiando resultado"
	copy_iso_from_vm "${vm_ip}"

	stop_vm

	echo ""
	echo "============================================="
	log_ok "BUILD COMPLETO!"
	echo "============================================="
	echo ""
	log_info "ISO disponível em: ${PROJECT_ROOT}/output/"
	ls -lh "${PROJECT_ROOT}/output/"*.iso 2>/dev/null || true
}

cmd_only_build() {
	ensure_vm_running

	local ip_list
	# shellcheck disable=SC2310
	if ! ip_list=$(get_vm_ip); then ip_list=""; fi

	local vm_ip
	vm_ip=$(wait_for_ssh "${ip_list}")

	log_step "Executando build na VM (apenas compilação)"
	run_build_in_vm "${vm_ip}"

	log_step "Copiando resultado"
	copy_iso_from_vm "${vm_ip}"

	log_ok "Build concluído! A VM continua em execução."
}

cmd_status() {
	if virsh list --all | grep -q "${VM_NAME}"; then
		virsh dominfo "${VM_NAME}"
		echo ""
		local vm_ip
		# shellcheck disable=SC2310
		if ! vm_ip=$(get_vm_ip); then
			vm_ip="não disponível"
		fi
		log_info "IP: ${vm_ip}"
	else
		log_warn "VM ${VM_NAME} não existe"
	fi
}

cmd_ssh() {
	ensure_vm_running

	local ip_list
	# shellcheck disable=SC2310
	if ! ip_list=$(get_vm_ip); then ip_list=""; fi

	local vm_ip
	vm_ip=$(wait_for_ssh "${ip_list}")

	local ssh_key="${PROJECT_ROOT}/.ssh/vm_key"

	log_info "Conectando a ${vm_ip}..."
	ssh -o StrictHostKeyChecking=no -i "${ssh_key}" root@"${vm_ip}"
}

cmd_destroy() {
	log_warn "Isso irá remover a VM e todos os dados!"
	read -p "Continuar? [y/N] " -n 1 -r
	echo

	if [[ ${REPLY} =~ ^[Yy]$ ]]; then
		virsh destroy "${VM_NAME}" 2>/dev/null || true
		virsh undefine "${VM_NAME}" --remove-all-storage 2>/dev/null || true
		log_ok "VM removida"
	fi
}

# =============================================================================
# MAIN
# =============================================================================

main() {
	local cmd="${1:-build}"

	check_root

	mkdir -p "${PROJECT_ROOT}/logs" "${PROJECT_ROOT}/output"

	case "${cmd}" in
	build) cmd_build ;;
	only-build | rebuild) cmd_only_build ;;
	setup) bash "${SCRIPT_DIR}/setup_host.sh" ;;
	create-vm) bash "${SCRIPT_DIR}/create_vm.sh" ;;
	status) cmd_status ;;
	ssh) cmd_ssh ;;
	stop) stop_vm ;;
	destroy) cmd_destroy ;;
	help | -h) show_help ;;
	*)
		log_error "Comando desconhecido: ${cmd}"
		show_help
		exit 1
		;;
	esac
}

main "$@"
