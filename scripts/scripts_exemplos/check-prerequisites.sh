#!/bin/bash
# ==============================================================================
# check-prerequisites.sh - Verificação de Ambiente DEBIAN NAS
#
# Valida se o ambiente possui todas as dependências necessárias para build
# e testes do projeto DEBIAN NAS.
# ==============================================================================

set -euo pipefail

# Cores
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[38;5;39m'
readonly NC='\033[0m'

# Contadores
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# Funções de saída
log_info() { printf "${BLUE}[INFO]${NC} %s\n" "$*"; }
log_ok() {
	printf "${GREEN}[OK]${NC} %s\n" "$*"
	((CHECKS_PASSED++))
}
log_warn() {
	printf "${YELLOW}[WARN]${NC} %s\n" "$*"
	((CHECKS_WARNING++))
}
log_error() {
	printf "${RED}[FAIL]${NC} %s\n" "$*"
	((CHECKS_FAILED++))
}
log_section() { printf "\n${CYAN}▶ %s${NC}\n" "$*"; }

# Verificar Docker
check_docker() {
	log_section "Verificando Docker"

	if ! command -v docker &>/dev/null; then
		log_error "Docker não encontrado"
		log_info "Instale com: sudo apt install docker.io"
		return 1
	fi
	log_ok "Docker instalado"

	if ! docker info &>/dev/null; then
		log_error "Docker não está rodando ou usuário sem permissões"
		log_info "Execute: sudo usermod -aG docker $USER && newgrp docker"
		return 1
	fi
	log_ok "Docker daemon acessível"

	# Verificar versão
	local version
	version=$(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1)
	log_info "Versão Docker: $version"
}

# Verificar espaço em disco
check_disk_space() {
	log_section "Verificando Espaço em Disco"

	local required_gb=10
	local available_gb

	available_gb=$(df -BG . | tail -1 | awk '{print $4}' | tr -d 'G')

	if [[ $available_gb -lt $required_gb ]]; then
		log_error "Espaço insuficiente: ${available_gb}GB disponível, ${required_gb}GB necessários"
		return 1
	fi
	log_ok "Espaço suficiente: ${available_gb}GB disponíveis"
}

# Verificar KVM (para testes)
check_kvm() {
	log_section "Verificando KVM (para testes em VM)"

	if ! command -v kvm &>/dev/null && ! command -v qemu-system-x86_64 &>/dev/null; then
		log_warn "KVM/QEMU não encontrado (necessário apenas para testes)"
		log_info "Instale com: sudo apt install qemu-kvm libvirt-daemon-system"
		return 0
	fi
	log_ok "KVM/QEMU disponível"

	if [[ ! -e /dev/kvm ]]; then
		log_warn "/dev/kvm não existe - virtualização pode estar desabilitada na BIOS"
	else
		log_ok "Dispositivo /dev/kvm disponível"
	fi

	if ! command -v virsh &>/dev/null; then
		log_warn "virsh não encontrado (necessário apenas para testes com make test-iso)"
	else
		log_ok "virsh disponível"
	fi
}

# Verificar permissões
check_permissions() {
	log_section "Verificando Permissões"

	# Verificar se pode usar --privileged no Docker
	if [[ $EUID -ne 0 ]]; then
		log_warn "Não está rodando como root - build pode falhar sem sudo"
		log_info "Para build local: sudo make iso"
		log_info "Para CI/CD: sudo é configurado no workflow"
	else
		log_ok "Executando como root (necessário para --privileged)"
	fi

	# Verificar permissões de escrita nos diretórios
	local dirs=("debian-nas/output" "debian-nas/logs" "debian-nas/cache")
	for dir in "${dirs[@]}"; do
		if [[ ! -d "$dir" ]]; then
			log_info "Criando diretório: $dir"
			mkdir -p "$dir"
		fi

		if [[ -w "$dir" ]]; then
			log_ok "Permissão de escrita em: $dir"
		else
			log_error "Sem permissão de escrita em: $dir"
		fi
	done
}

# Verificar conectividade
check_connectivity() {
	log_section "Verificando Conectividade de Rede"

	local mirrors=(
		"http://ftp.br.debian.org/debian/"
		"https://get.zfsbootmenu.org/"
		"https://api.github.com/"
	)

	for mirror in "${mirrors[@]}"; do
		if curl -s --head --fail "$mirror" &>/dev/null; then
			log_ok "Acessível: $mirror"
		else
			log_warn "Não acessível: $mirror (build pode falhar)"
		fi
	done
}

# Verificar estrutura do projeto
check_project_structure() {
	log_section "Verificando Estrutura do Projeto"

	local required_files=(
		"debian-nas/Makefile"
		"debian-nas/config-overrides/auto/config"
		"debian-nas/scripts/docker/Dockerfile"
		"debian-nas/scripts/docker/entrypoint.sh"
	)

	for file in "${required_files[@]}"; do
		if [[ -f "$file" ]]; then
			log_ok "Arquivo encontrado: $file"
		else
			log_error "Arquivo ausente: $file"
		fi
	done

	# Verificar diretórios
	local required_dirs=(
		"debian-nas/config-overrides/config"
		"debian-nas/scripts/vm"
	)

	for dir in "${required_dirs[@]}"; do
		if [[ -d "$dir" ]]; then
			log_ok "Diretório encontrado: $dir"
		else
			log_warn "Diretório ausente: $dir"
		fi
	done
}

# Resumo
check_summary() {
	log_section "Resumo da Verificação"

	echo ""
	printf "${GREEN}✔ %d verificações passaram${NC}\n" "$CHECKS_PASSED"
	printf "${YELLOW}⚠ %d avisos${NC}\n" "$CHECKS_WARNING"
	printf "${RED}✖ %d verificações falharam${NC}\n" "$CHECKS_FAILED"
	echo ""

	if [[ $CHECKS_FAILED -eq 0 ]]; then
		printf "${GREEN}✅ Ambiente pronto para build!${NC}\n"
		echo ""
		echo "Próximos passos:"
		echo "  1. make builder    # Criar imagem Docker do builder"
		echo "  2. make iso        # Gerar ISO DEBIAN NAS"
		echo "  3. make test-iso   # Testar em VM (se KVM disponível)"
		return 0
	else
		printf "${RED}❌ Ambiente NÃO está pronto${NC}\n"
		echo ""
		echo "Corrija os erros acima antes de prosseguir."
		return 1
	fi
}

# Main
main() {
	echo ""
	printf "${CYAN}╔════════════════════════════════════════════════════════╗${NC}\n"
	printf "${CYAN}║${NC}     🔍 Verificação de Ambiente DEBIAN NAS              ${CYAN}║${NC}\n"
	printf "${CYAN}╚════════════════════════════════════════════════════════╝${NC}\n"
	echo ""

	check_docker
	check_disk_space
	check_kvm
	check_permissions
	check_connectivity
	check_project_structure
	check_summary
}

main "$@"
