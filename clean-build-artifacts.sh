#!/bin/bash
# Script de limpeza para artefatos gerados pelo debian_trixie_builder-v2.sh
# Remove diretórios temporários, arquivos gerados e imagens Docker
# Preserva apenas código fonte e configurações essenciais

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Lista de arquivos/diretórios essenciais (não remover)
ESSENTIAL_FILES=(
	"build-debian-trixie-zbm.sh"
	"docker-entrypoint.sh"
	"download-zfsbootmenu.sh"
	"include/"
	"tests/"
	".gitignore"
	".agent/"
	".zencoder/"
	".zenflow/"
	"debian_readme.md"
	"quick_start_guide.md"
	"plans/"
)

# Lista de artefatos a remover
ARTIFACTS_TO_REMOVE=(
	"build/"
	"output/"
	"config/"
	"live-build-config/"
	"Dockerfile"
)

print_message() {
	local type="$1"
	local message="$2"

	case "${type}" in
	"info")
		echo -e "${BLUE}[INFO]${NC} ${message}"
		;;
	"success")
		echo -e "${GREEN}[SUCESSO]${NC} ${message}"
		;;
	"warning")
		echo -e "${YELLOW}[AVISO]${NC} ${message}"
		;;
	"error")
		echo -e "${RED}[ERRO]${NC} ${message}" >&2
		;;
	esac
}

# Verifica se arquivo/diretório é essencial
is_essential() {
	local item="$1"

	for essential in "${ESSENTIAL_FILES[@]}"; do
		if [[ ${item} == "${essential}" ]]; then
			return 0
		fi
	done
	return 1
}

# Calcula tamanho antes da limpeza
calculate_size() {
	local total_size=0

	for artifact in "${ARTIFACTS_TO_REMOVE[@]}"; do
		if [[ -e ${artifact} ]]; then
			local size
			# Use awk to sum multiple lines if they occur, although du -sb should return one
			size=$(du -sb "${artifact}" 2>/dev/null | cut -f1 | awk '{s+=$1} END {print s+0}')
			total_size=$((total_size + size))
		fi
	done

	# Adiciona tamanho da imagem Docker se existir
	# Usamos --no-trunc para garantir que pegamos o tamanho real se necessário,
	# e somamos caso haja mais de uma imagem com a mesma tag (raro mas possível)
	if docker images debian-trixie-zbm-builder:latest -q >/dev/null 2>&1; then
		local docker_size
		docker_size=$(docker images debian-trixie-zbm-builder:latest --format "{{.Size}}" |
			sed 's/B$//; s/KB$/ * 1024/; s/MB$/ * 1024 * 1024/; s/GB$/ * 1024 * 1024 * 1024/' |
			bc 2>/dev/null | awk '{s+=$1} END {print s+0}')
		total_size=$((total_size + docker_size))
	fi

	echo "${total_size}"
}

# Formata tamanho em formato legível
format_size() {
	local size="$1"

	if ((size < 1024)); then
		echo "${size} B"
	elif ((size < 1048576)); then
		echo "$((size / 1024)) KB"
	elif ((size < 1073741824)); then
		echo "$((size / 1048576)) MB"
	else
		echo "$((size / 1073741824)) GB"
	fi
}

# Verificação de segurança
safety_check() {
	print_message "warning" "VERIFICAÇÃO DE SEGURANÇA:"
	echo "Este script irá remover os seguintes artefatos:"

	for artifact in "${ARTIFACTS_TO_REMOVE[@]}"; do
		if [[ -e ${artifact} ]]; then
			echo "  - ${artifact}"
		fi
	done

	if docker images debian-trixie-zbm-builder:latest -q >/dev/null 2>&1; then
		echo "  - Imagem Docker: debian-trixie-zbm-builder:latest"
	fi

	echo ""
	echo "Arquivos ESSENCIAIS que serão PRESERVADOS:"
	for essential in "${ESSENTIAL_FILES[@]}"; do
		if [[ -e ${essential} ]]; then
			echo "  - ${essential}"
		fi
	done

	echo ""
	echo "Tem certeza que deseja continuar? (digite 'SIM' para confirmar)"
	read -r confirm
	if [[ ${confirm} != "SIM" ]]; then
		print_message "info" "Operação cancelada pelo usuário."
		exit 0
	fi
}

# Remove artefatos
clean_artifacts() {
	local removed_count=0
	local space_saved=0

	print_message "info" "Iniciando limpeza de artefatos..."

	for artifact in "${ARTIFACTS_TO_REMOVE[@]}"; do
		if [[ -e ${artifact} ]]; then
			local size_before
			size_before=$(du -sb "${artifact}" 2>/dev/null | cut -f1 || echo "0")

			print_message "info" "Removendo: ${artifact}"
			rm -rf "${artifact}"

			space_saved=$((space_saved + size_before))
			removed_count=$((removed_count + 1))
		else
			print_message "info" "Ignorando (não existe): ${artifact}"
		fi
	done

	# Remove imagem Docker
	if docker images debian-trixie-zbm-builder:latest -q >/dev/null 2>&1; then
		print_message "info" "Removendo imagem Docker: debian-trixie-zbm-builder:latest"
		docker rmi debian-trixie-zbm-builder:latest >/dev/null 2>&1 || true
		removed_count=$((removed_count + 1))
	fi

	# Remove containers parados relacionados
	local stopped_containers
	stopped_containers=$(docker ps -a --filter ancestor=debian-trixie-zbm-builder --filter status=exited -q 2>/dev/null || true)
	if [[ -n ${stopped_containers} ]]; then
		print_message "info" "Removendo containers parados relacionados..."
		# shellcheck disable=SC2086
		docker rm ${stopped_containers} >/dev/null 2>&1 || true
	fi

	# Limpa cache de build do Docker (resolve problema de camadas antigas)
	print_message "info" "Limpando cache de build do Docker..."
	docker builder prune -f >/dev/null 2>&1 || true

	print_message "success" "Limpeza concluída!"
	print_message "success" "Artefatos removidos: ${removed_count}"
	print_message "success" "Espaço liberado: $(format_size "${space_saved}")"
}

# Função principal
main() {
	print_message "info" "=== LIMPEZA DE ARTEFATOS DO BUILD ==="

	# Calcula espaço que será liberado
	local estimated_size
	estimated_size=$(calculate_size)

	if ((estimated_size > 0)); then
		print_message "info" "Espaço estimado a ser liberado: $(format_size "${estimated_size}")"
	else
		print_message "warning" "Nenhum artefato encontrado para limpeza."
		exit 0
	fi

	echo ""
	safety_check
	echo ""

	clean_artifacts

	print_message "success" "Repositório limpo com sucesso!"
	print_message "info" "Para reconstruir, execute: ./build-debian-trixie-zbm.sh build"
}

# Executa função principal
main "$@"
