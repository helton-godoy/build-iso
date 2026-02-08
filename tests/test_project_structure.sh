#!/usr/bin/env bash
# @TEST_SCRIPT: test_project_structure.sh
# @TEST_CATEGORY: structure
# @TEST_DESC: Valida a estrutura de diretórios e arquivos essenciais do projeto
# @TEST_DEP: find, test
# @TEST_TARGETS: logs/, output/, scripts/, config-overrides/, docs/
# @TEST_EXIT: 0=estrutura válida, 1=diretórios/arquivos faltando

set -euo pipefail

echo "Verificando a estrutura de diretórios do projeto..."

# Nova estrutura do projeto conforme docs/PROJECT_STRUCTURE.md
DIRS=(
	"logs"
	"output"
	"scripts/docker"
	"scripts/vm"
	"config-overrides/config/hooks"
	"config-overrides/config/package-lists"
	"config-overrides/config/includes.chroot"
	"config-overrides/config/includes.binary"
)

MISSING=0

for dir in "${DIRS[@]}"; do
	if [[ -d "$dir" ]]; then
		echo "PASS: Diretório '$dir' existe."
	else
		echo "FAIL: Diretório '$dir' não encontrado."
		MISSING=$((MISSING + 1))
	fi
done

if [[ $MISSING -gt 0 ]]; then
	echo "Erro: $MISSING diretórios obrigatórios estão faltando."
	exit 1
fi

# Verifica documentação
if [[ -f "docs/PROJECT_STRUCTURE.md" ]]; then
	echo "PASS: Documentação docs/PROJECT_STRUCTURE.md existe."
else
	echo "FAIL: Documentação docs/PROJECT_STRUCTURE.md não encontrada."
	exit 1
fi

# Verifica scripts essenciais
SCRIPTS=(
	"scripts/docker/Dockerfile"
	"scripts/docker/entrypoint.sh"
	"scripts/vm/vm-setup.sh"
	"scripts/download-zfsbootmenu.sh"
)

for script in "${SCRIPTS[@]}"; do
	if [[ -f "$script" ]]; then
		echo "PASS: Script '$script' existe."
	else
		echo "FAIL: Script '$script' não encontrado."
		MISSING=$((MISSING + 1))
	fi
done

if [[ $MISSING -gt 0 ]]; then
	echo "Erro: $MISSING arquivos obrigatórios estão faltando."
	exit 1
fi

echo "Estrutura do projeto validada com sucesso!"
exit 0
